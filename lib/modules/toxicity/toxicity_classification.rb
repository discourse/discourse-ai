# frozen_string_literal: true

module DiscourseAI
  module Toxicity
    class ToxicityClassification
      CLASSIFICATION_LABELS = %i[
        toxicity
        severe_toxicity
        obscene
        identity_attack
        insult
        threat
        sexual_explicit
      ]

      def type
        :toxicity
      end

      def can_classify?(target)
        content_of(target).present?
      end

      def should_flag_based_on?(classification_data)
        return false if !SiteSetting.ai_toxicity_flag_automatically

        # We only use one model for this classification.
        # Classification_data looks like { model_name => classification }
        _model_used, data = classification_data.to_a.first

        CLASSIFICATION_LABELS.any? do |label|
          data[label] >= SiteSetting.send("ai_toxicity_flag_threshold_#{label}")
        end
      end

      def request(target_to_classify)
        data =
          ::DiscourseAI::InferenceManager.perform!(
            "#{SiteSetting.ai_toxicity_inference_service_api_endpoint}/api/v1/classify",
            SiteSetting.ai_toxicity_inference_service_api_model,
            content_of(target_to_classify),
            SiteSetting.ai_toxicity_inference_service_api_key,
          )

        { available_model => data }
      end

      private

      def available_model
        SiteSetting.ai_toxicity_inference_service_api_model
      end

      def content_of(target_to_classify)
        return target_to_classify.message if target_to_classify.is_a?(ChatMessage)

        if target_to_classify.post_number == 1
          "#{target_to_classify.topic.title}\n#{target_to_classify.raw}"
        else
          target_to_classify.raw
        end
      end
    end
  end
end
