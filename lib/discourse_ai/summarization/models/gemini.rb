# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Models
      class Gemini < Base
        def display_name
          "Google Gemini #{model}"
        end

        def correctly_configured?
          SiteSetting.ai_gemini_api_key.present?
        end

        def configuration_hint
          I18n.t(
            "discourse_ai.summarization.configuration_hint",
            count: 1,
            setting: "ai_gemini_api_key",
          )
        end
      end
    end
  end
end
