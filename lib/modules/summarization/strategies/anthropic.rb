# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Strategies
      class Anthropic < ::Summarization::Base
        def self.name
          "Anthropic"
        end

        def correctly_configured?
          SiteSetting.ai_anthropic_api_key.present?
        end

        def configuration_hint
          I18n.t(
            "discourse_ai.summarization.configuration_hint",
            count: 1,
            setting: "ai_anthropic_api_key",
          )
        end

        def summarize(content_text)
          response =
            ::DiscourseAi::Inference::AnthropicCompletions.perform!(
              prompt(content_text),
              anthropic_model,
            ).dig(:completion)

          Nokogiri::HTML5.fragment(response).at("ai").text
        end

        def prompt(content)
          truncated_content =
            ::DiscourseAi::Tokenizer::AnthropicTokenizer.truncate(content, max_length - 50)

          "Human: Summarize the following article that is inside <input> tags.
          Please include only the summary inside <ai> tags.

          <input>##{truncated_content}</input>


          Assistant:
        "
        end

        private

        def anthropic_model
          SiteSetting.ai_summarization_anthropic_service_model
        end

        def max_length
          lengths = { "claude-v1" => 9000, "claude-v1-100k" => 100_000 }

          lengths[anthropic_model]
        end
      end
    end
  end
end
