# frozen_string_literal: true

if defined?(DiscourseAutomation)
  DiscourseAutomation::Scriptable.add("llm_triage") do
    version 1
    run_in_background

    placeholder :post

    triggerables %i[post_created_edited]

    # TODO move to triggerables
    field :include_personal_messages, component: :boolean

    # Inputs
    field :model,
          component: :choices,
          required: true,
          extra: {
            content: DiscourseAi::Automation.available_models,
          }
    field :system_prompt, component: :message, required: false
    field :search_for_text, component: :text, required: true
    field :max_post_tokens, component: :text
    field :stop_sequences, component: :text_list, required: false
    field :temperature, component: :text

    # Actions
    field :category, component: :category
    field :tags, component: :tags
    field :hide_topic, component: :boolean
    field :flag_post, component: :boolean
    field :flag_type,
          component: :choices,
          required: false,
          extra: {
            content: DiscourseAi::Automation.flag_types,
          },
          default: "review"
    field :canned_reply_user, component: :user
    field :canned_reply, component: :message
    field :reply_persona,
          component: :choices,
          extra: {
            content: DiscourseAi::Automation.available_persona_choices,
          }
    field :whisper, component: :boolean

    script do |context, fields|
      post = context["post"]

      post = context["post"]
      next if post&.user&.bot?

      if post.topic.private_message?
        include_personal_messages = fields.dig("include_personal_messages", "value")
        next if !include_personal_messages
      end

      canned_reply = fields.dig("canned_reply", "value")
      canned_reply_user = fields.dig("canned_reply_user", "value")
      reply_persona_id = fields["reply_persona"]["value"]
      whisper = fields["whisper"]["value"]

      # nothing to do if we already replied
      next if post.user.username == canned_reply_user
      next if post.raw.strip == canned_reply.to_s.strip

      system_prompt = fields["system_prompt"]["value"]
      search_for_text = fields["search_for_text"]["value"]
      model = fields["model"]["value"]

      category_id = fields.dig("category", "value")
      tags = fields.dig("tags", "value")
      hide_topic = fields.dig("hide_topic", "value")
      flag_post = fields.dig("flag_post", "value")
      flag_type = fields.dig("flag_type", "value")
      max_post_tokens = fields.dig("max_post_tokens", "value").to_i
      temperature = fields.dig("temperature", "value")
      if temperature == "" || temperature.nil?
        temperature = nil
      else
        temperature = temperature.to_f
      end

      max_post_tokens = nil if max_post_tokens <= 0

      stop_sequences = fields.dig("stop_sequences", "value")

      begin
        RateLimiter.new(
          Discourse.system_user,
          "llm_triage_#{post.id}",
          SiteSetting.ai_automation_max_triage_per_post_per_minute,
          1.minute,
        ).performed!

        RateLimiter.new(
          Discourse.system_user,
          "llm_triage",
          SiteSetting.ai_automation_max_triage_per_minute,
          1.minute,
        ).performed!

        DiscourseAi::Automation::LlmTriage.handle(
          post: post,
          model: model,
          search_for_text: search_for_text,
          system_prompt: system_prompt,
          category_id: category_id,
          tags: tags,
          canned_reply: canned_reply,
          canned_reply_user: canned_reply_user,
          reply_persona_id: reply_persona_id,
          whisper: whisper,
          hide_topic: hide_topic,
          flag_post: flag_post,
          flag_type: flag_type.to_s.to_sym,
          max_post_tokens: max_post_tokens,
          stop_sequences: stop_sequences,
          automation: self.automation,
          temperature: temperature,
        )
      rescue => e
        Discourse.warn_exception(e, message: "llm_triage: skipped triage on post #{post.id}")
      end
    end
  end
end
