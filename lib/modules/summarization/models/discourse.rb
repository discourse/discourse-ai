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

        def summarize_in_chunks(contents, _opts)
          chunks = []

          section = ""
          last_chunk =
            contents.each do |item|
              new_content = format_content_item(item)

              if tokenizer.can_expand_tokens?(section, new_content, max_tokens - reserved_tokens)
                section += new_content
              else
                chunks << section
                section = new_content
              end
            end

          chunks << section if section.present?

          chunks.map { |chunk| completion(chunk) }
        end

        def concatenate_summaries(summaries)
          completion(summaries.join("\n"))
        end

        def summarize_with_truncation(contents, opts)
          text_to_summarize = contents.map { |c| format_content_item(c) }.join
          truncated_content =
            ::DiscourseAi::Tokenizer::BertTokenizer.truncate(text_to_summarize, max_tokens)

          completion(truncated_content)
        end

        private

        def reserved_tokens
          0
        end

        def completion(prompt)
          ::DiscourseAi::Inference::DiscourseClassifier.perform!(
            "#{SiteSetting.ai_summarization_discourse_service_api_endpoint}/api/v1/classify",
            model,
            prompt,
            SiteSetting.ai_summarization_discourse_service_api_key,
          ).dig(:summary_text)
        end

        def tokenizer
          DiscourseAi::Tokenizer::BertTokenizer
        end
      end
    end
  end
end
