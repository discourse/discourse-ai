# frozen_string_literal: true

if defined?(DiscourseAutomation)
  module DiscourseAutomation::LlmReport
  end

  DiscourseAutomation::Scriptable.add("llm_report") do
    version 1
    triggerables %i[recurring]

    field :sender, component: :user, required: true
    field :receivers, component: :users
    field :topic_id, component: :text
    field :title, component: :text
    field :days, component: :text, required: true, default_value: 7
    field :offset, component: :text, required: true, default_value: 0
    field :instructions,
          component: :message,
          required: true,
          default_value: DiscourseAi::Automation::ReportRunner.default_instructions
    field :sample_size, component: :text, required: true, default_value: 100
    field :tokens_per_post, component: :text, required: true, default_value: 150

    field :model,
          component: :choices,
          required: true,
          extra: {
            content: DiscourseAi::Automation::AVAILABLE_MODELS,
          }

    field :priority_group, component: :group
    field :categories, component: :categories
    field :tags, component: :tags

    field :exclude_categories, component: :categories
    field :exclude_tags, component: :tags

    field :allow_secure_categories, component: :boolean

    field :top_p, component: :text, required: true, default_value: 0.1
    field :temperature, component: :text, required: true, default_value: 0.2

    field :suppress_notifications, component: :boolean
    field :debug_mode, component: :boolean

    script do |context, fields, automation|
      begin
        sender = fields.dig("sender", "value")
        receivers = fields.dig("receivers", "value")
        topic_id = fields.dig("topic_id", "value")
        title = fields.dig("title", "value")
        model = fields.dig("model", "value")
        category_ids = fields.dig("categories", "value")
        tags = fields.dig("tags", "value")
        allow_secure_categories = !!fields.dig("allow_secure_categories", "value")
        debug_mode = !!fields.dig("debug_mode", "value")
        sample_size = fields.dig("sample_size", "value")
        instructions = fields.dig("instructions", "value")
        days = fields.dig("days", "value")
        offset = fields.dig("offset", "value").to_i
        priority_group = fields.dig("priority_group", "value")
        tokens_per_post = fields.dig("tokens_per_post", "value")

        exclude_category_ids = fields.dig("exclude_categories", "value")
        exclude_tags = fields.dig("exclude_tags", "value")

        # set defaults in code to support easy migration for old rules
        top_p = 0.1
        top_p = fields.dig("top_p", "value").to_f if fields.dig("top_p", "value")

        temperature = 0.2
        temperature = fields.dig("temperature", "value").to_f if fields.dig("temperature", "value")

        suppress_notifications = !!fields.dig("suppress_notifications", "value")
        DiscourseAi::Automation::ReportRunner.run!(
          sender_username: sender,
          receivers: receivers,
          topic_id: topic_id,
          title: title,
          model: model,
          category_ids: category_ids,
          tags: tags,
          allow_secure_categories: allow_secure_categories,
          debug_mode: debug_mode,
          sample_size: sample_size,
          instructions: instructions,
          days: days,
          offset: offset,
          priority_group_id: priority_group,
          tokens_per_post: tokens_per_post,
          exclude_category_ids: exclude_category_ids,
          exclude_tags: exclude_tags,
          temperature: temperature,
          top_p: top_p,
          suppress_notifications: suppress_notifications,
        )
      rescue => e
        Discourse.warn_exception e, message: "Error running LLM report!"
        if Rails.env.development?
          p e
          puts e.backtrace
        end
      end
    end
  end
end
