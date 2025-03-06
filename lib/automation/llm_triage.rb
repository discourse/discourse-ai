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
        stop_sequences: nil,
        temperature: nil,
        whisper: nil,
        reply_persona_id: nil
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
            temperature: temperature,
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
          if reply_persona_id.present?
            ai_persona = AiPersona.find_by(id: persona_id)
            if ai_persona.present?
              persona_class = ai_persona.class_instance
              persona = persona_class.new

              bot_user = ai_persona.user
              if bot_user.nil?
                bot = DiscourseAi::AiBot::Bot.as(bot_user, persona: persona)
                playground = DiscourseAi::AiBot::Playground.new(bot)

                playground.reply_to(post, whisper: whisper, context_style: :topic)
              end
            end
          elsif canned_reply.present?
            post_type = whisper ? Post.types[:whisper] : Post.types[:regular]
            PostCreator.create!(
              user,
              topic_id: post.topic_id,
              raw: canned_reply,
              reply_to_post_number: post.post_number,
              skip_validations: true,
              post_type: post_type,
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
              result =
                PostActionCreator.new(
                  Discourse.system_user,
                  post,
                  PostActionType.types[:spam],
                  message: score_reason,
                  queue_for_review: true,
                ).perform

              if flag_type == :spam_silence
                if result.success?
                  SpamRule::AutoSilence.new(post.user, post).silence_user
                else
                  Rails.logger.warn(
                    "llm_triage: unable to flag post as spam, post action failed for #{post.id} with error: '#{result.errors.full_messages.join(",").truncate(3000)}'",
                  )
                end
              end
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
