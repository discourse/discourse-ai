# frozen_string_literal: true

module ::DiscourseAI
  module Toxicity
    class ChatMessageClassifier < Classifier
      def content
        @object.message
      end

      def store_classification
        PluginStore.set(
          "toxicity",
          "chat_message_#{@object.id}",
          {
            classification: @classification,
            model: SiteSetting.ai_toxicity_inference_service_api_model,
            date: Time.now.utc,
          },
        )
      end

      def flag!
        Chat::ChatReviewQueue.new.flag_message(
          @object,
          Guardian.new(flagger),
          ReviewableScore.types[:inappropriate],
        )
      end
    end
  end
end
