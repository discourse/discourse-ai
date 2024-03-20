# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Models
      class Anthropic < Base
        def display_name
          "Anthropic's #{model}"
        end

        def correctly_configured?
          SiteSetting.ai_anthropic_api_key.present? ||
            DiscourseAi::Completions::Endpoints::AwsBedrock.correctly_configured?("claude-2")
        end

        def configuration_hint
          I18n.t(
            "discourse_ai.summarization.configuration_hint",
            count: 1,
            setting: "ai_anthropic_api_key",
          )
        end
      end
    end
  end
end
