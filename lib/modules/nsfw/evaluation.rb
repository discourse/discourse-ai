# frozen_string_literal: true

module DiscourseAI
  module NSFW
    class Evaluation
      def perform(upload)
        result = { verdict: false, evaluation: {} }

        SiteSetting
          .ai_nsfw_models
          .split("|")
          .each do |model|
            model_result = evaluate_with_model(model, upload).symbolize_keys!

            result[:evaluation][model.to_sym] = model_result

            result[:verdict] = send("#{model}_verdict?", model_result)
          end

        result
      end

      private

      def evaluate_with_model(model, upload)
        upload_url = Discourse.store.cdn_url(upload.url)
        upload_url = "#{Discourse.base_url_no_prefix}#{upload_url}" if upload_url.starts_with?("/")

        DiscourseAI::InferenceManager.perform!(
          "#{SiteSetting.ai_nsfw_inference_service_api_endpoint}/api/v1/classify",
          model,
          upload_url,
          SiteSetting.ai_nsfw_inference_service_api_key,
        )
      end

      def opennsfw2_verdict?(clasification)
        clasification.values.first.to_i >= SiteSetting.ai_nsfw_flag_threshold_general
      end

      def nsfw_detector_verdict?(classification)
        classification.each do |key, value|
          next if key == :neutral
          return true if value.to_i >= SiteSetting.send("ai_nsfw_flag_threshold_#{key}")
        end
        false
      end
    end
  end
end
