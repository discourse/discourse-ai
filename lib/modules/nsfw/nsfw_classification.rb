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

      def get_verdicts(classification_data)
        classification_data
          .map do |model_name, classifications|
            verdict =
              classifications.values.any? do |data|
                send("#{model_name}_verdict?", data.except(:neutral, :target_classified_type))
              end

            [model_name, verdict]
          end
          .to_h
      end

      def should_flag_based_on?(verdicts)
        return false if !SiteSetting.ai_nsfw_flag_automatically

        verdicts.values.any?
      end

      def request(target_to_classify)
        uploads_to_classify = content_of(target_to_classify)

        available_models.reduce({}) do |memo, model|
          memo[model] = uploads_to_classify.reduce({}) do |upl_memo, upload|
            upl_memo[upload.id] = evaluate_with_model(model, upload).merge(
              target_classified_type: upload.class.name,
            )

            upl_memo
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
        classification.any? do |key, value|
          value.to_i >= SiteSetting.send("ai_nsfw_flag_threshold_#{key}")
        end
      end
    end
  end
end
