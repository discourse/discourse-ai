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
        automation: nil
      )
        if category_id.blank? && tags.blank? && canned_reply.blank? && hide_topic.blank? &&
             flag_post.blank?
          raise ArgumentError, "llm_triage: no action specified!"
        end

        s_prompt = system_prompt.to_s.sub("%%POST%%", "") # Backwards-compat. We no longer sub this.
        prompt = DiscourseAi::Completions::Prompt.new(s_prompt)
        prompt.push(type: :user, content: "title: #{post.topic.title}\n#{post.raw}")

        result = nil

        llm = DiscourseAi::Completions::Llm.proxy(model)

        result =
          llm.generate(
            prompt,
            temperature: 0,
            max_tokens: 700, # ~500 words
            user: Discourse.system_user,
            feature_name: "llm_triage",
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
          changes[:tags] = tags if SiteSetting.tagging_enabled? && tags.present?

          if changes.present?
            first_post = post.topic.posts.where(post_number: 1).first
            changes[:bypass_bump] = true
            changes[:skip_validations] = true
            first_post.revise(Discourse.system_user, changes)
          end

          post.topic.update!(visible: false) if hide_topic

          if flag_post
            reviewable =
              ReviewablePost.needs_review!(target: post, created_by: Discourse.system_user)

            score_reason =
              I18n
                .t("discourse_automation.scriptables.llm_triage.flagged_post")
                .sub("%%LLM_RESPONSE%%", result)
                .sub("%%AUTOMATION_ID%%", automation&.id.to_s)
                .sub("%%AUTOMATION_NAME%%", automation&.name.to_s)

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
