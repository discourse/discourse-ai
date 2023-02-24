# frozen_string_literal: true

module DiscourseAI
  module NSFW
    class NSFWClassification
      def type
        :nsfw
      end

      def can_classify?(target)
        content_of(target).present?
      end

      def should_flag_based_on?(classification_data)
        return false if !SiteSetting.ai_nsfw_flag_automatically

        # Flat representation of each model classification of each upload.
        # Each element looks like [model_name, data]
        all_classifications = classification_data.values.flatten.map { |x| x.to_a.flatten }

        all_classifications.any? { |(model_name, data)| send("#{model_name}_verdict?", data) }
      end

      def request(target_to_classify)
        uploads_to_classify = content_of(target_to_classify)

        uploads_to_classify.reduce({}) do |memo, upload|
          memo[upload.id] = available_models.reduce({}) do |per_model, model|
            per_model[model] = evaluate_with_model(model, upload)
            per_model
          end

          memo
        end
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

      def available_models
        SiteSetting.ai_nsfw_models.split("|")
      end

      def content_of(target_to_classify)
        target_to_classify.uploads.to_a.select { |u| FileHelper.is_supported_image?(u.url) }
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
