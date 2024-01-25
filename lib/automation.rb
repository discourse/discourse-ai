# frozen_string_literal: true

module DiscourseAi
  module Automation
    AVAILABLE_MODELS = [
      { id: "gpt-4-turbo", name: "discourse_automation.ai_models.gpt_4_turbo" },
      { id: "gpt-4", name: "discourse_automation.ai_models.gpt_4" },
      { id: "gpt-3.5-turbo", name: "discourse_automation.ai_models.gpt_3_5_turbo" },
      { id: "claude-2", name: "discourse_automation.ai_models.claude_2" },
      { id: "gemini-pro", name: "discourse_automation.ai_models.gemini_pro" },
    ]
  end
end
