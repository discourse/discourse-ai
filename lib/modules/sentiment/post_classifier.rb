# frozen_string_literal: true

module ::DiscourseAI
  module Sentiment
    class PostClassifier
      def classify!(post)
        available_models.each do |model|
          classification = request_classification(post, model)

          store_classification(post, model, classification)
        end
      end

      def available_models
        SiteSetting.ai_sentiment_models.split("|")
      end

      private

      def request_classification(post, model)
        ::DiscourseAI::InferenceManager.perform!(
          "#{SiteSetting.ai_sentiment_inference_service_api_endpoint}/api/v1/classify",
          model,
          content(post),
          SiteSetting.ai_sentiment_inference_service_api_key,
        )
      end

      def content(post)
        post.post_number == 1 ? "#{post.topic.title}\n#{post.raw}" : post.raw
      end

      def store_classification(post, model, classification)
        PostCustomField.create!(
          post_id: post.id,
          name: "ai-sentiment-#{model}",
          value: { classification: classification }.to_json,
        )
      end
    end
  end
end
