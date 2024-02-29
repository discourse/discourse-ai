# frozen_string_literal: true

if defined?(DiscourseAutomation)
  DiscourseAutomation::Scriptable::LLM_TRIAGE = "llm_triage"

  DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scriptable::LLM_TRIAGE) do
    version 1
    run_in_background

    placeholder :post

    triggerables %i[post_created_edited]

    field :system_prompt,
          component: :message,
          required: true,
          validator: ->(input) do
            if !input.include?("%%POST%%")
              I18n.t(
                "discourse_automation.scriptables.#{DiscourseAutomation::Scriptable::LLM_TRIAGE}.system_prompt_missing_post_placeholder",
              )
            end
          end,
          accepts_placeholders: true
    field :search_for_text, component: :text, required: true
    field :model,
          component: :choices,
          required: true,
          extra: {
            content: DiscourseAi::Automation::AVAILABLE_MODELS,
          }
    field :category, component: :category
    field :tags, component: :tags
    field :hide_topic, component: :boolean
    field :flag_post, component: :boolean
    field :canned_reply, component: :message
    field :canned_reply_user, component: :user

    script do |context, fields, automation|
      post = context["post"]
      system_prompt = fields["system_prompt"]["value"]
      search_for_text = fields["search_for_text"]["value"]
      model = fields["model"]["value"]

      if !%w[gpt-4 gpt-3-5-turbo claude-2].include?(model)
        Rails.logger.warn("llm_triage: model #{model} is not supported")
        next
      end

      category_id = fields.dig("category", "value")
      tags = fields.dig("tags", "value")
      hide_topic = fields.dig("hide_topic", "value")
      flag_post = fields.dig("flag_post", "value")
      canned_reply = fields.dig("canned_reply", "value")
      canned_reply_user = fields.dig("canned_reply_user", "value")

      if post.raw.strip == canned_reply.to_s.strip
        # nothing to do if we already replied
        next
      end

      begin
        DiscourseAi::Automation::LlmTriage.handle(
          post: post,
          model: model,
          search_for_text: search_for_text,
          system_prompt: system_prompt,
          category_id: category_id,
          tags: tags,
          canned_reply: canned_reply,
          canned_reply_user: canned_reply_user,
          hide_topic: hide_topic,
          flag_post: flag_post,
          automation: automation,
        )
      rescue => e
        Discourse.warn_exception(e, message: "llm_triage: failed to run inference")
      end
    end
  end
end
