# frozen_string_literal: true

module DiscourseAi
  module Automation
    AVAILABLE_MODELS = [
      { id: "gpt-4-turbo", name: "discourse_automation.ai_models.gpt_4_turbo" },
      { id: "gpt-4", name: "discourse_automation.ai_models.gpt_4" },
      { id: "gpt-3.5-turbo", name: "discourse_automation.ai_models.gpt_3_5_turbo" },
      { id: "gemini-pro", name: "discourse_automation.ai_models.gemini_pro" },
      { id: "gemini-1.5-pro", name: "discourse_automation.ai_models.gemini_1_5_pro" },
      { id: "claude-2", name: "discourse_automation.ai_models.claude_2" },
      { id: "claude-3-sonnet", name: "discourse_automation.ai_models.claude_3_sonnet" },
      { id: "claude-3-opus", name: "discourse_automation.ai_models.claude_3_opus" },
      { id: "claude-3-haiku", name: "discourse_automation.ai_models.claude_3_haiku" },
      {
        id: "mistralai/Mixtral-8x7B-Instruct-v0.1",
        name: "discourse_automation.ai_models.mixtral_8x7b_instruct_v0_1",
      },
      {
        id: "mistralai/Mistral-7B-Instruct-v0.2",
        name: "discourse_automation.ai_models.mistral_7b_instruct_v0_2",
      },
      { id: "command-r", name: "discourse_automation.ai_models.command_r" },
      { id: "command-r-plus", name: "discourse_automation.ai_models.command_r_plus" },
    ]

    def self.translate_model(model)
      llm_model = LlmModel.find_by(name: model)
      return "custom:#{llm_model.id}" if llm_model

      return "google:#{model}" if model.start_with? "gemini"
      return "open_ai:#{model}" if model.start_with? "gpt"
      return "cohere:#{model}" if model.start_with? "command"

      if model.start_with? "claude"
        if DiscourseAi::Completions::Endpoints::AwsBedrock.correctly_configured?(model)
          return "aws_bedrock:#{model}"
        else
          return "anthropic:#{model}"
        end
      end

      if model.start_with?("mistral")
        if DiscourseAi::Completions::Endpoints::Vllm.correctly_configured?(model)
          return "vllm:#{model}"
        elsif DiscourseAi::Completions::Endpoints::HuggingFace.correctly_configured?(model)
          "hugging_face:#{model}"
        else
          "ollama:mistral"
        end
      end

      raise "Unknown model #{model}"
    end
  end
end
