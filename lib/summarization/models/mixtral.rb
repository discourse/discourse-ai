# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Models
      class Mixtral < Base
        def display_name
          "MistralAI's #{model}"
        end

        def correctly_configured?
          SiteSetting.ai_hugging_face_api_url.present? || SiteSetting.ai_vllm_endpoint_srv.present?
        end

        def configuration_hint
          I18n.t(
            "discourse_ai.summarization.configuration_hint",
            count: 1,
            settings: %w[ai_hugging_face_api_url ai_vllm_endpoint_srv],
          )
        end
      end
    end
  end
end
