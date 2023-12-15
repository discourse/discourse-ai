# frozen_string_literal: true

if defined?(DiscourseAutomation)
  module DiscourseAutomation::LlmReport
  end

  DiscourseAutomation::Scriptable::LLM_REPORT = "llm_report"

  DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scriptable::LLM_REPORT) do
    version 1
    triggerables %i[recurring]

    field :sender, component: :user, required: true
    field :receiver, component: :user, required: true
    field :title, component: :text, required: true
    field :instructions, component: :message, required: true, default_value: "test test"
    field :sample_size, component: :text, required: true, default_value: 100

    field :model,
          component: :choices,
          required: true,
          extra: {
            content: DiscourseAi::Automation::AVAILABLE_MODELS,
          }

    field :category, component: :category
    field :tags, component: :tags

    field :allow_secure_categories, component: :boolean

    script do |context, fields, automation|
      sender = context["sender"]["value"]
      receiver = context["receiver"]["value"]
      title = context["title"]["value"]
      model = context["model"]["value"]
      category_id = context.dig("category", "value")
      tags = context.dig("tags", "value")
      allow_secure_categories = !!context.dig("allow_secure_categories", "value")

      DiscourseAi::Automation::ReportRunner.run!(
        sender_username: sender,
        receiver_username: receiver,
        title: title,
        model: model,
        category_id: category_id,
        tags: tags,
        allow_secure_categories: allow_secure_categories,
      )
    end
  end
end
