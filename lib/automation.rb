# frozen_string_literal: true

module DiscourseAi
  module Automation
    AVAILABLE_MODELS = [
      { id: "gpt-4-turbo", name: "discourse_automation.ai_models.gpt_4_turbo" },
      { id: "gpt-4", name: "discourse_automation.ai_models.gpt_4" },
      { id: "gpt-3.5-turbo", name: "discourse_automation.ai_models.gpt_3_5_turbo" },
      { id: "gemini-pro", name: "discourse_automation.ai_models.gemini_pro" },
      { id: "claude-2", name: "discourse_automation.ai_models.claude_2" },
      { id: "claude-3-sonnet", name: "discourse_automation.ai_models.claude_3_sonnet" },
      { id: "claude-3-opus", name: "discourse_automation.ai_models.claude_3_opus" },
    ]

    def self.translate_model(model)
      return "google:gemini-pro" if model == "gemini-pro"
      return "open_ai:#{model}" if model.start_with? "gpt"

      if model.start_with? "claude"
        if DiscourseAi::Completions::Endpoints::AwsBedrock.correctly_configured?(model)
          return "aws_bedrock:#{model}"
        else
          return "anthropic:#{model}"
        end
      end

      raise "Unknown model #{model}"
    end
  end
end
