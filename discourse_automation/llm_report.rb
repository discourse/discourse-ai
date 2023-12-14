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
    field :system_prompt, component: :message, required: true
    field :instructions, component: :message, required: true

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
      p fields
      p context
    end
  end
end
