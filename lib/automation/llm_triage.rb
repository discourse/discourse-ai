# frozen_string_literal: true
#
module DiscourseAi
  module Automation
    module LlmTriage
      def self.handle(
        post:,
        model:,
        search_for_text:,
        system_prompt:,
        category_id: nil,
        tags: nil,
        canned_reply: nil,
        canned_reply_user: nil,
        hide_topic: nil,
        flag_post: nil,
        flag_type: nil,
        automation: nil,
        max_post_tokens: nil,
        stop_sequences: nil
      )
        if category_id.blank? && tags.blank? && canned_reply.blank? && hide_topic.blank? &&
             flag_post.blank?
          raise ArgumentError, "llm_triage: no action specified!"
        end

        llm = DiscourseAi::Completions::Llm.proxy(model)

        s_prompt = system_prompt.to_s.sub("%%POST%%", "") # Backwards-compat. We no longer sub this.
        prompt = DiscourseAi::Completions::Prompt.new(s_prompt)

        content = "title: #{post.topic.title}\n#{post.raw}"

        content = llm.tokenizer.truncate(content, max_post_tokens) if max_post_tokens.present?

        prompt.push(type: :user, content: content, upload_ids: post.upload_ids)

        result = nil

        result =
          llm.generate(
            prompt,
            temperature: 0,
            max_tokens: 700, # ~500 words
            user: Discourse.system_user,
            stop_sequences: stop_sequences,
            feature_name: "llm_triage",
            feature_context: {
              automation_id: automation&.id,
              automation_name: automation&.name,
            },
          )&.strip

        if result.present? && result.downcase.include?(search_for_text.downcase)
          user = User.find_by_username(canned_reply_user) if canned_reply_user.present?
          user = user || Discourse.system_user
          if canned_reply.present?
            PostCreator.create!(
              user,
              topic_id: post.topic_id,
              raw: canned_reply,
              reply_to_post_number: post.post_number,
              skip_validations: true,
            )
          end

          changes = {}
          changes[:category_id] = category_id if category_id.present?
          if SiteSetting.tagging_enabled? && tags.present?
            changes[:tags] = post.topic.tags.map(&:name).concat(tags)
          end

          if changes.present?
            first_post = post.topic.posts.where(post_number: 1).first
            changes[:bypass_bump] = true
            changes[:skip_validations] = true
            first_post.revise(Discourse.system_user, changes)
          end

          post.topic.update!(visible: false) if hide_topic

          if flag_post
            score_reason =
              I18n
                .t("discourse_automation.scriptables.llm_triage.flagged_post")
                .sub("%%LLM_RESPONSE%%", result)
                .sub("%%AUTOMATION_ID%%", automation&.id.to_s)
                .sub("%%AUTOMATION_NAME%%", automation&.name.to_s)

            if flag_type == :spam || flag_type == :spam_silence
              PostActionCreator.new(
                Discourse.system_user,
                post,
                PostActionType.types[:spam],
                message: score_reason,
                queue_for_review: true,
              ).perform

              SpamRule::AutoSilence.new(post.user, post).silence_user if flag_type == :spam_silence
            else
              reviewable =
                ReviewablePost.needs_review!(target: post, created_by: Discourse.system_user)

              reviewable.add_score(
                Discourse.system_user,
                ReviewableScore.types[:needs_approval],
                reason: score_reason,
                force_review: true,
              )
            end
          end
        end
      end
    end
  end
end
