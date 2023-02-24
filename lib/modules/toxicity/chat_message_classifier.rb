# frozen_string_literal: true

module ::DiscourseAI
  module Toxicity
    class ChatMessageClassifier < Classifier
      private

      def content(chat_message)
        chat_message.message
      end

      def store_classification(chat_message, classification)
        PluginStore.set(
          "toxicity",
          "chat_message_#{chat_message.id}",
          {
            classification: classification,
            model: SiteSetting.ai_toxicity_inference_service_api_model,
            date: Time.now.utc,
          },
        )
      end

      def flag!(chat_message, _toxic_labels)
        Chat::ChatReviewQueue.new.flag_message(
          chat_message,
          Guardian.new(flagger),
          ReviewableScore.types[:inappropriate],
        )
      end
    end
  end
end
