# frozen_string_literal: true

module DiscourseAi
  module Sentiment
    class SentimentClassification
      def type
        :sentiment
      end

      def available_classifiers
        DiscourseAi::Sentiment::SentimentSiteSettingJsonSchema.values
      end

      def can_classify?(target)
        content_of(target).present?
      end

      def get_verdicts(_)
        available_classifiers.reduce({}) do |memo, model|
          memo[model.model_name] = false
          memo
        end
      end

      def should_flag_based_on?(_verdicts)
        # We don't flag based on sentiment classification.
        false
      end

      def request(target_to_classify)
        target_content = content_of(target_to_classify)

        available_classifiers.reduce({}) do |memo, model|
          memo[model.model_name] = request_with(target_content, model)
          memo
        end
      end

      private

      def request_with(content, model_config)
        result = ::DiscourseAi::Inference::HuggingFaceTextEmbeddings.classify(content, model_config)
        hash_result = {}
        result.each { |r| hash_result[r[:label]] = r[:score] }
        hash_result
      end

      def content_of(target_to_classify)
        content =
          if target_to_classify.post_number == 1
            "#{target_to_classify.topic.title}\n#{target_to_classify.raw}"
          else
            target_to_classify.raw
          end

        Tokenizer::BertTokenizer.truncate(content, 512)
      end
    end
  end
end
