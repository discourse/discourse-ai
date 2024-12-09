# frozen_string_literal: true

module DiscourseAi
  module AiModeration
    class SpamScanner
      POSTS_TO_SCAN = 3
      MINIMUM_EDIT_DIFFERENCE = 10
      EDIT_DELAY_MINUTES = 10

      def self.new_post(post)
        return if !enabled?
        return if !should_scan_post?(post)

        Jobs.enqueue(:ai_spam_scan, post_id: post.id)
      end

      def self.edited_post(post)
        return if !enabled?
        return if !should_scan_post?(post)
        return if scanned_max_times?(post)

        previous_version = post.revisions.last&.modifications&.dig("raw", 0)
        current_version = post.raw

        # Skip if we can't determine the difference or if change is too small
        return if !significant_change?(previous_version, current_version)

        last_scan = AiSpamLog.where(post_id: post.id).order(created_at: :desc).first

        if last_scan && last_scan.created_at > EDIT_DELAY_MINUTES.minutes.ago
          # Schedule delayed job if too soon after last scan
          delay_minutes =
            ((last_scan.created_at + EDIT_DELAY_MINUTES.minutes) - Time.current).to_i / 60
          Jobs.enqueue_in(delay_minutes.minutes, :ai_spam_scan, post_id: post.id)
        else
          Jobs.enqueue(:ai_spam_scan, post_id: post.id)
        end
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

      def self.perform_scan(post)
        return if !enabled?
        return if !should_scan_post?(post)

        settings = AiModerationSetting.spam
        return if !settings || !settings.llm_model

        llm = settings.llm_model.to_llm
        custom_instructions = settings.custom_instructions.presence

        system_prompt = build_system_prompt(custom_instructions)
        prompt = DiscourseAi::Completions::Prompt.new(system_prompt)

        context = build_context(post)
        prompt.push(type: :user, content: context)

        begin
          result =
            llm.generate(
              prompt,
              temperature: 0.1,
              max_tokens: 100,
              user: Discourse.system_user,
              feature_name: "spam_detection",
              feature_context: {
                post_id: post.id,
              },
            )&.strip

          is_spam = (result.present? && result.downcase.include?("spam"))

          log = AiApiAuditLog.order(id: :desc).where(feature_name: "spam_detection").first

          AiSpamLog.transaction do
            AiSpamLog.create!(
              post: post,
              llm_model: settings.llm_model,
              ai_api_audit_log: log,
              is_spam: is_spam,
              payload: context,
            )
            handle_spam(post, result) if is_spam
          end

        rescue StandardError => e
          if Rails.env.test?
            raise e
          end
          Discourse.warn_exception(e, message: "Error in SpamScanner for post #{post.id}")
        end
      end

      private

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

        context << "\nPost Content:"
        context << post.raw
        context.join("\n")
      end

      def self.build_system_prompt(custom_instructions)
        base_prompt = <<~PROMPT
          You are a spam detection system. Analyze the following post content and context.
          Respond with "SPAM" if the post is spam, or "NOT_SPAM" if it's legitimate.

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

        if custom_instructions.present?
          base_prompt += "\n\nAdditional site-specific instructions:\n#{custom_instructions}"
        end

        base_prompt
      end

      def self.handle_spam(post, result)
        SpamRule::AutoSilence.new(post.user, post).silence_user

        reason = I18n.t("discourse_ai.spam_detection.flag_reason", result: result)

        PostActionCreator.new(
          Discourse.system_user,
          post,
          PostActionType.types[:spam],
          message: reason,
          queue_for_review: true,
        ).perform
      end
    end
  end
end
