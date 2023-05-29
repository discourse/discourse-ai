# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Strategies
      class DiscourseAi < ::Summarization::Base
        def self.name
          "Discourse AI"
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

        def summarize(content_text)
          ::DiscourseAi::Inference::DiscourseClassifier.perform!(
            "#{SiteSetting.ai_summarization_discourse_service_api_endpoint}/api/v1/classify",
            discourse_ai_model,
            prompt(content_text),
            SiteSetting.ai_summarization_discourse_service_api_key,
          ).dig(:summary_text)
        end

        def prompt(text)
          ::DiscourseAi::Tokenizer::BertTokenizer.truncate(text, max_length)
        end

        private

        def discourse_ai_model
          SiteSetting.ai_summarization_discourse_service_model
        end

        def max_length
          lengths = {
            "bart-large-cnn-samsum" => 1024,
            "flan-t5-base-samsum" => 512,
            "long-t5-tglobal-base-16384-book-summary" => 16_384,
          }

          lengths[discourse_ai_model]
        end
      end
    end
  end
end
