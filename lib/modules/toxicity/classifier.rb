# frozen_string_literal: true

module ::DiscourseAI
  module Toxicity
    class Classifier
      CLASSIFICATION_LABELS = %w[
        toxicity
        severe_toxicity
        obscene
        identity_attack
        insult
        threat
        sexual_explicit
      ]

      def classify!(target)
        classification = request_classification(target)

        store_classification(target, classification)

        toxic_labels = filter_toxic_labels(classification)

        flag!(target, toxic_labels) if should_flag_based_on?(toxic_labels)
      end

      protected

      def flag!(_target, _toxic_labels)
        raise NotImplemented
      end

      def store_classification(_target, _classification)
        raise NotImplemented
      end

      def content(_target)
        raise NotImplemented
      end

      def flagger
        Discourse.system_user
      end

      private

      def request_classification(target)
        ::DiscourseAI::InferenceManager.perform!(
          "#{SiteSetting.ai_toxicity_inference_service_api_endpoint}/api/v1/classify",
          SiteSetting.ai_toxicity_inference_service_api_model,
          content(target),
          SiteSetting.ai_toxicity_inference_service_api_key,
        )
      end

      def filter_toxic_labels(classification)
        CLASSIFICATION_LABELS.filter do |label|
          classification[label] >= SiteSetting.send("ai_toxicity_flag_threshold_#{label}")
        end
      end

      def should_flag_based_on?(toxic_labels)
        SiteSetting.ai_toxicity_flag_automatically && toxic_labels.present?
      end
    end
  end
end
