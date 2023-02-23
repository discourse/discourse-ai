# frozen_string_literal: true

module DiscourseAI
  module NSFW
    class Evaluation
      AVAILABLE_MODELS = %w[opennsfw2 nsfw_detector]

      def perform(upload)
        result = { verdict: false, evaluation: {} }

        AVAILABLE_MODELS.each do |model|
          model_result = evaluate_with_model(model, upload).symbolize_keys!

          model_result.values.each do |classification_prob|
            if classification_prob.to_i >= SiteSetting.ai_nsfw_probability_threshold
              result[:verdict] = true
            end
          end

          result[:evaluation][model.to_sym] = model_result
        end

        result
      end

      private

      def evaluate_with_model(model, upload)
        DiscourseAI::InferenceManager.perform!(
          "#{SiteSetting.ai_nsfw_inference_service_api_endpoint}/api/v1/classify",
          model,
          Discourse.store.cdn_url(upload.url),
          SiteSetting.ai_nsfw_inference_service_api_key,
        )
      end
    end
  end
end
