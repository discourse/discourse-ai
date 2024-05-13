# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Models
      class CustomLlm < Base
        def display_name
          custom_llm.display_name
        end

        def correctly_configured?
          if Rails.env.development?
            SiteSetting.ai_ollama_endpoint.present?
          else
            SiteSetting.ai_hugging_face_api_url.present? ||
              SiteSetting.ai_vllm_endpoint_srv.present? || SiteSetting.ai_vllm_endpoint.present?
          end
        end

        def configuration_hint
          I18n.t(
            "discourse_ai.summarization.configuration_hint",
            count: 1,
            setting: "ai_hugging_face_api_url",
          )
        end

        def model
          model_name
        end

        private

        def custom_llm
          id = model.split(":").last
          @llm ||= LlmModel.find_by(id: id)
        end
      end
    end
  end
end
