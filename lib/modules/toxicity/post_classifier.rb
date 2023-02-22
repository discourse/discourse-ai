# frozen_string_literal: true

module ::DiscourseAI
  module Toxicity
    class PostClassifier < Classifier
      def content
        object.post_number == 1 ? "#{object.topic.title}\n#{object.raw}" : object.raw
      end

      def store_classification
        PostCustomField.create!(
          post_id: @object.id,
          name: "toxicity",
          value: {
            classification: @classification,
            model: SiteSetting.ai_toxicity_inference_service_api_model,
          }.to_json,
        )
      end

      def flag!
        PostActionCreator.create(flagger, @object, :inappropriate, reason: @reasons.join("/"))
        @object.publish_change_to_clients! :acted
      end
    end
  end
end
