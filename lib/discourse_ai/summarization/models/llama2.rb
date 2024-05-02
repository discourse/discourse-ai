# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Models
      class Llama2 < Base
        def display_name
          "Llama2's #{SiteSetting.ai_hugging_face_model_display_name.presence || model}"
        end

        def correctly_configured?
          SiteSetting.ai_hugging_face_api_url.present?
        end

        def configuration_hint
          I18n.t(
            "discourse_ai.summarization.configuration_hint",
            count: 1,
            setting: "ai_hugging_face_api_url",
          )
        end
      end
    end
  end
end
