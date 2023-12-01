# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Strategies
      class TruncateContent < ::Summarization::Base
        def initialize(completion_model)
          @completion_model = completion_model
        end

        attr_reader :completion_model

        delegate :correctly_configured?,
                 :display_name,
                 :configuration_hint,
                 :model,
                 to: :completion_model

        def summarize(content, _user, &on_partial_blk)
          opts = content.except(:contents)

          {
            summary: summarize_with_truncation(content[:contents], opts, &on_partial_blk),
            chunks: [],
          }
        end

        private

        def format_content_item(item)
          "(#{item[:id]} #{item[:poster]} said: #{item[:text]} "
        end

        def summarize_with_truncation(contents, opts)
          text_to_summarize = contents.map { |c| format_content_item(c) }.join
          truncated_content =
            ::DiscourseAi::Tokenizer::BertTokenizer.truncate(
              text_to_summarize,
              completion_model.available_tokens,
            )

          completion(truncated_content)
        end

        def completion(prompt)
          ::DiscourseAi::Inference::DiscourseClassifier.perform!(
            "#{SiteSetting.ai_summarization_discourse_service_api_endpoint}/api/v1/classify",
            completion_model.model,
            prompt,
            SiteSetting.ai_summarization_discourse_service_api_key,
          ).dig(:summary_text)
        end
      end
    end
  end
end
