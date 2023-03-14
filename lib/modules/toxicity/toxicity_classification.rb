# frozen_string_literal: true

module DiscourseAi
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

      def get_verdicts(classification_data)
        # We only use one model for this classification.
        # Classification_data looks like { model_name => classification }
        _model_used, data = classification_data.to_a.first

        verdict =
          CLASSIFICATION_LABELS.any? do |label|
            data[label] >= SiteSetting.send("ai_toxicity_flag_threshold_#{label}")
          end

        { available_model => verdict }
      end

      def should_flag_based_on?(verdicts)
        return false if !SiteSetting.ai_toxicity_flag_automatically

        verdicts.values.any?
      end

      def request(target_to_classify)
        data =
          ::DiscourseAi::Inference::DiscourseClassifier.perform!(
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
