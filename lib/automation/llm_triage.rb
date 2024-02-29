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
        automation:
      )
        if category_id.blank? && tags.blank? && canned_reply.blank? && hide_topic.blank? &&
             flag_post.blank?
          raise ArgumentError, "llm_triage: no action specified!"
        end

        post_template = +""
        post_template << "title: #{post.topic.title}\n"
        post_template << "#{post.raw}"

        filled_system_prompt = system_prompt.sub("%%POST%%", post_template)

        if filled_system_prompt == system_prompt
          raise ArgumentError, "llm_triage: system_prompt does not contain %%POST%% placeholder"
        end

        result = nil

        llm = DiscourseAi::Completions::Llm.proxy(translate_model(model))

        result =
          llm.generate(
            filled_system_prompt,
            temperature: 0,
            max_tokens: llm.tokenizer.tokenize(search_for_text).length * 2 + 10,
            user: Discourse.system_user,
          )

        if result.strip == search_for_text.strip
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

          ReviewablePost.needs_review!(target: post, created_by: Discourse.system_user) if flag_post
        end
      end

      def self.translate_model(model)
        return "google:gemini-pro" if model == "gemini-pro"
        return "open_ai:#{model}" if model != "claude-2"

        if DiscourseAi::Completions::Endpoints::AwsBedrock.correctly_configured?("claude-2")
          "aws_bedrock:claude-2"
        else
          "anthropic:claude-2"
        end
      end
    end
  end
end
