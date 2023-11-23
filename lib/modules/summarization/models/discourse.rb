# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Models
      class Discourse < Base
        def display_name
          "Discourse AI's #{model}"
        end

        def correctly_configured?
          SiteSetting.ai_summarization_discourse_service_api_endpoint.present? &&
            SiteSetting.ai_summarization_discourse_service_api_key.present?
        end

        def configuration_hint
          I18n.t(
            "discourse_ai.summarization.configuration_hint",
            count: 2,
            settings:
              "ai_summarization_discourse_service_api_endpoint, ai_summarization_discourse_service_api_key",
          )
        end

        private

        def reserved_tokens
          0
        end
      end
    end
  end
end
