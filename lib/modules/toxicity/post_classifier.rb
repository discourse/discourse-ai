# frozen_string_literal: true

module ::DiscourseAI
  module Toxicity
    class PostClassifier < Classifier
      private

      def content(post)
        post.post_number == 1 ? "#{post.topic.title}\n#{post.raw}" : post.raw
      end

      def store_classification(post, classification)
        PostCustomField.create!(
          post_id: post.id,
          name: "toxicity",
          value: {
            classification: classification,
            model: SiteSetting.ai_toxicity_inference_service_api_model,
          }.to_json,
        )
      end

      def flag!(target, toxic_labels)
        ::DiscourseAI::FlagManager.new(target, reasons: toxic_labels).flag!
      end
    end
  end
end
