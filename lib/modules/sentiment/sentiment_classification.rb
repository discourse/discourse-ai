# frozen_string_literal: true

module DiscourseAI
  module Sentiment
    class SentimentClassification
      def type
        :sentiment
      end

      def available_models
        SiteSetting.ai_sentiment_models.split("|")
      end

      def can_classify?(target)
        content_of(target).present?
      end

      def get_verdicts(_)
        available_models.reduce({}) do |memo, model|
          memo[model] = false
          memo
        end
      end

      def should_flag_based_on?(_verdicts)
        # We don't flag based on sentiment classification.
        false
      end

      def request(target_to_classify)
        target_content = content_of(target_to_classify)

        available_models.reduce({}) do |memo, model|
          memo[model] = request_with(model, target_content)
          memo
        end
      end

      private

      def request_with(model, content)
        ::DiscourseAI::Inference::DiscourseClassifier.perform!(
          "#{SiteSetting.ai_sentiment_inference_service_api_endpoint}/api/v1/classify",
          model,
          content,
          SiteSetting.ai_sentiment_inference_service_api_key,
        )
      end

      def content_of(target_to_classify)
        if target_to_classify.post_number == 1
          "#{target_to_classify.topic.title}\n#{target_to_classify.raw}"
        else
          target_to_classify.raw
        end
      end
    end
  end
end
