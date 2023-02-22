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

      def initialize(object)
        @object = object
      end

      def content
      end

      def classify!
        @classification =
          ::DiscourseAI::InferenceManager.perform!(
            "#{SiteSetting.ai_toxicity_inference_service_api_endpoint}/api/v1/classify",
            SiteSetting.ai_toxicity_inference_service_api_model,
            content,
            SiteSetting.ai_toxicity_inference_service_api_key,
          )
        store_classification
        consider_flagging
      end

      def store_classification
      end

      def automatic_flag_enabled?
        SiteSetting.ai_toxicity_flag_automatically
      end

      def consider_flagging
        return unless automatic_flag_enabled?
        @reasons =
          CLASSIFICATION_LABELS.filter do |label|
            @classification[label] >= SiteSetting.send("ai_toxicity_flag_threshold_#{label}")
          end

        flag! unless @reasons.empty?
      end

      def flagger
        User.find_by(id: -1)
      end

      def flag!
      end
    end
  end
end
