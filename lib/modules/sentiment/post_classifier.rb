# frozen_string_literal: true

module ::DiscourseAI
  module Sentiment
    class PostClassifier
      SENTIMENT_LABELS = %w[anger disgust fear joy neutral sadness surprise]

      SENTIMENT_LABELS = %w[negative neutral positive]

      def initialize(object)
        @object = object
      end

      def content
        @object.post_number == 1 ? "#{@object.topic.title}\n#{@object.raw}" : @object.raw
      end

      def classify!
        SiteSetting
          .ai_sentiment_models
          .split("|")
          .each do |model|
            classification =
              ::DiscourseAI::InferenceManager.perform!(
                "#{SiteSetting.ai_sentiment_inference_service_api_endpoint}/api/v1/classify",
                model,
                content,
                SiteSetting.ai_sentiment_inference_service_api_key,
              )

            store_classification(model, classification)
          end
      end

      def store_classification(model, classification)
        PostCustomField.create!(
          post_id: @object.id,
          name: "ai-sentiment-#{model}",
          value: { classification: classification }.to_json,
        )
      end
    end
  end
end
