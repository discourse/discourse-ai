# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Strategies
      class OpenAi < ::Summarization::Base
        def display_name
          "Open AI's #{model}"
        end

        def correctly_configured?
          SiteSetting.ai_openai_api_key.present?
        end

        def configuration_hint
          I18n.t(
            "discourse_ai.summarization.configuration_hint",
            count: 1,
            setting: "ai_openai_api_key",
          )
        end

        def summarize(content_text)
          ::DiscourseAi::Inference::OpenAiCompletions.perform!(prompt(content_text), model).dig(
            :choices,
            0,
            :message,
            :content,
          )
        end

        def prompt(content)
          truncated_content =
            ::DiscourseAi::Tokenizer::OpenAiTokenizer.truncate(content, max_length - 50)

          messages = [{ role: "system", content: <<~TEXT }]
            Summarize the following article:\n\n#{truncated_content}
          TEXT
        end

        private

        def max_length
          lengths = { "gpt-3.5-turbo" => 4096, "gpt-4" => 8192 }

          lengths[model]
        end
      end
    end
  end
end
