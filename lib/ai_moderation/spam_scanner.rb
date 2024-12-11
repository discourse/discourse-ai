# frozen_string_literal: true

module DiscourseAi
  module AiModeration
    class SpamScanner
      POSTS_TO_SCAN = 3
      MINIMUM_EDIT_DIFFERENCE = 10
      EDIT_DELAY_MINUTES = 10
      MAX_AGE_TO_SCAN = 1.day
      MAX_RAW_SCAN_LENGTH = 5000

      SHOULD_SCAN_POST_CUSTOM_FIELD = "discourse_ai_should_scan_post"

      def self.new_post(post)
        return if !enabled?
        return if !should_scan_post?(post)

        flag_post_for_scanning(post)
      end

      def self.ensure_flagging_user!
        if !SiteSetting.ai_spam_detection_user_id.present?
          User.transaction do
            # prefer a "high" id for this bot
            id = User.where("id > -20").minimum(:id) - 1
            id = User.minimum(:id) - 1 if id == -100

            user =
              User.create!(
                id: id,
                username: UserNameSuggester.suggest("discourse_ai_spam"),
                name: "Discourse AI Spam Scanner",
                email: "#{SecureRandom.hex(10)}@invalid.invalid",
                active: true,
                approved: true,
                trust_level: TrustLevel[4],
                admin: true,
              )
            Group.user_trust_level_change!(user.id, user.trust_level)

            SiteSetting.ai_spam_detection_user_id = user.id
          end
        end
      end

      def self.flagging_user
        user = nil
        if SiteSetting.ai_spam_detection_user_id.present?
          user = User.find_by(id: SiteSetting.ai_spam_detection_user_id)
        end
        user || Discourse.system_user
      end

      def self.after_cooked_post(post)
        return if !enabled?
        return if !should_scan_post?(post)
        return if !post.custom_fields[SHOULD_SCAN_POST_CUSTOM_FIELD]
        return if post.updated_at < MAX_AGE_TO_SCAN.ago

        last_scan = AiSpamLog.where(post_id: post.id).order(created_at: :desc).first

        if last_scan && last_scan.created_at > EDIT_DELAY_MINUTES.minutes.ago
          delay_minutes =
            ((last_scan.created_at + EDIT_DELAY_MINUTES.minutes) - Time.current).to_i / 60
          Jobs.enqueue_in(delay_minutes.minutes, :ai_spam_scan, post_id: post.id)
        else
          Jobs.enqueue(:ai_spam_scan, post_id: post.id)
        end
      end

      def self.edited_post(post)
        return if !enabled?
        return if !should_scan_post?(post)
        return if scanned_max_times?(post)

        previous_version = post.revisions.last&.modifications&.dig("raw", 0)
        current_version = post.raw

        return if !significant_change?(previous_version, current_version)

        flag_post_for_scanning(post)
      end

      def self.flag_post_for_scanning(post)
        post.custom_fields[SHOULD_SCAN_POST_CUSTOM_FIELD] = "true"
        post.save_custom_fields
      end

      def self.enabled?
        SiteSetting.ai_spam_detection_enabled && SiteSetting.discourse_ai_enabled
      end

      def self.should_scan_post?(post)
        return false if !post.present?
        return false if post.user.trust_level > TrustLevel[1]
        return false if post.topic.private_message?
        if Post
             .where(user_id: post.user_id)
             .joins(:topic)
             .where(topic: { archetype: Archetype.default })
             .limit(4)
             .count > 3
          return false
        end
        true
      end

      def self.scanned_max_times?(post)
        AiSpamLog.where(post_id: post.id).count >= 3
      end

      def self.significant_change?(previous_version, current_version)
        return true if previous_version.nil? # First edit should be scanned

        # Use Discourse's built-in levenshtein implementation
        distance =
          ScreenedEmail.levenshtein(previous_version.to_s[0...1000], current_version.to_s[0...1000])

        distance >= MINIMUM_EDIT_DIFFERENCE
      end

      def self.test_post(post, custom_instructions: nil)
        settings = AiModerationSetting.spam
        llm = settings.llm_model.to_llm
        custom_instructions = custom_instructions || settings.custom_instructions.presence
        context = build_context(post)
        prompt = completion_prompt(post, context: context, custom_instructions: custom_instructions)

        result =
          llm.generate(
            prompt,
            temperature: 0.1,
            max_tokens: 5,
            user: Discourse.system_user,
            feature_name: "spam_detection_test",
            feature_context: {
              post_id: post.id,
            },
          )&.strip

        history = nil
        AiSpamLog
          .where(post: post)
          .order(:created_at)
          .limit(100)
          .each do |log|
            history ||= +"Scan History:\n"
            history << "date: #{log.created_at} is_spam: #{log.is_spam}\n"
          end

        log = +"Scanning #{post.url}\n\n"

        if history
          log << history
          log << "\n"
        end

        log << "LLM: #{settings.llm_model.name}\n\n"
        log << "System Prompt: #{build_system_prompt(custom_instructions)}\n\n"
        log << "Context: #{context}\n\n"
        log << "Result: #{result}\n\n"

        is_spam = check_if_spam(result)

        prompt.push(type: :model, content: result)
        prompt.push(type: :user, content: "Explain your reasoning")

        reasoning =
          llm.generate(
            prompt,
            temperature: 0.1,
            max_tokens: 100,
            user: Discourse.system_user,
            feature_name: "spam_detection_test",
            feature_context: {
              post_id: post.id,
            },
          )&.strip

        log << "Reasoning: #{reasoning}"

        { is_spam: is_spam, log: log }
      end

      def self.completion_prompt(post, context:, custom_instructions:)
        system_prompt = build_system_prompt(custom_instructions)
        prompt = DiscourseAi::Completions::Prompt.new(system_prompt)
        args = { type: :user, content: context }
        upload_ids = post.upload_ids
        args[:upload_ids] = upload_ids.take(3) if upload_ids.present?
        prompt.push(**args)
        prompt
      end

      def self.perform_scan(post)
        return if !enabled?
        return if !should_scan_post?(post)

        settings = AiModerationSetting.spam
        return if !settings || !settings.llm_model

        context = build_context(post)
        llm = settings.llm_model.to_llm
        custom_instructions = settings.custom_instructions.presence
        prompt = completion_prompt(post, context: context, custom_instructions: custom_instructions)

        begin
          result =
            llm.generate(
              prompt,
              temperature: 0.1,
              max_tokens: 5,
              user: Discourse.system_user,
              feature_name: "spam_detection",
              feature_context: {
                post_id: post.id,
              },
            )&.strip

          is_spam = check_if_spam(result)

          log = AiApiAuditLog.order(id: :desc).where(feature_name: "spam_detection").first
          AiSpamLog.transaction do
            log =
              AiSpamLog.create!(
                post: post,
                llm_model: settings.llm_model,
                ai_api_audit_log: log,
                is_spam: is_spam,
                payload: context,
              )
            handle_spam(post, log) if is_spam
          end
        rescue StandardError => e
          # we need retries otherwise stuff will not be handled
          Discourse.warn_exception(
            e,
            message: "Discourse AI: Error in SpamScanner for post #{post.id}",
          )
          raise e
        end
      end

      private

      def self.check_if_spam(result)
        (result.present? && result.strip.downcase.start_with?("spam"))
      end

      def self.build_context(post)
        context = []

        # Clear distinction between reply and new topic
        if post.is_first_post?
          context << "NEW TOPIC POST ANALYSIS"
          context << "- Topic title: #{post.topic.title}"
          context << "- Category: #{post.topic.category&.name}"
        else
          context << "REPLY POST ANALYSIS"
          context << "- In topic: #{post.topic.title}"
          context << "- Category: #{post.topic.category&.name}"
          context << "- Topic started by: #{post.topic.user.username}"

          # Include parent post context for replies
          if post.reply_to_post.present?
            parent = post.reply_to_post
            context << "\nReplying to #{parent.user.username}'s post:"
            context << "#{parent.raw[0..500]}..." if parent.raw.length > 500
            context << parent.raw if parent.raw.length <= 500
          end
        end

        context << "\nPost Author Information:"
        context << "- Username: #{post.user.username}"
        context << "- Account age: #{(Time.current - post.user.created_at).to_i / 86_400} days"
        context << "- Total posts: #{post.user.post_count}"
        context << "- Trust level: #{post.user.trust_level}"

        context << "\nPost Content (first #{MAX_RAW_SCAN_LENGTH} chars):\n"
        context << post.raw[0..MAX_RAW_SCAN_LENGTH]
        context.join("\n")
      end

      def self.build_system_prompt(custom_instructions)
        base_prompt = +<<~PROMPT
          You are a spam detection system. Analyze the following post content and context.
          Respond with "SPAM" if the post is spam, or "NOT_SPAM" if it's legitimate.

          - ALWAYS lead your reply with the word SPAM or NOT_SPAM - you are consumed via an API

          Consider the post type carefully:
          - For REPLY posts: Check if the response is relevant and topical to the thread
          - For NEW TOPIC posts: Check if it's a legitimate topic or spam promotion

          A post is spam if it matches any of these criteria:
          - Contains unsolicited commercial content or promotions
          - Has suspicious or unrelated external links
          - Shows patterns of automated/bot posting
          - Contains irrelevant content or advertisements
          - For replies: Completely unrelated to the discussion thread
          - Uses excessive keywords or repetitive text patterns
          - Shows suspicious formatting or character usage

          Be especially strict with:
          - Replies that ignore the previous conversation
          - Posts containing multiple unrelated external links
          - Generic responses that could be posted anywhere

          Be fair to:
          - New users making legitimate first contributions
          - Non-native speakers making genuine efforts to participate
          - Topic-relevant product mentions in appropriate contexts
        PROMPT

        base_prompt << "\n\n"
        base_prompt << <<~SITE_SPECIFIC
          Site Specific Information:
          - Site name: #{SiteSetting.title}
          - Site URL: #{Discourse.base_url}
          - Site description: #{SiteSetting.site_description}
          - Site top 10 categories: #{Category.where(read_restricted: false).order(posts_year: :desc).limit(10).pluck(:name).join(", ")}
        SITE_SPECIFIC

        if custom_instructions.present?
          base_prompt << "\n\nAdditional site-specific instructions provided by Staff:\n#{custom_instructions}"
        end

        base_prompt
      end

      def self.handle_spam(post, log)
        url = "#{Discourse.base_url}/admin/plugins/discourse-ai/ai-spam"
        reason = I18n.t("discourse_ai.spam_detection.flag_reason", url: url)

        result =
          PostActionCreator.new(
            flagging_user,
            post,
            PostActionType.types[:spam],
            reason: reason,
            queue_for_review: true,
          ).perform

        log.update!(reviewable: result.reviewable)
        SpamRule::AutoSilence.new(post.user, post).silence_user
        # this is required cause tl1 is not auto hidden
        # we want to also handle tl1
        hide_posts_and_topics(post.user)
      end

      def self.hide_posts_and_topics(user)
        Post
          .where(user_id: user.id)
          .where("created_at > ?", 24.hours.ago)
          .update_all(
            [
              "hidden = true, hidden_reason_id = COALESCE(hidden_reason_id, ?)",
              Post.hidden_reasons[:new_user_spam_threshold_reached],
            ],
          )
        topic_ids =
          Post
            .where(user_id: user.id, post_number: 1)
            .where("created_at > ?", 24.hours.ago)
            .select(:topic_id)

        Topic.where(id: topic_ids).update_all(visible: false)
      end
    end
  end
end
