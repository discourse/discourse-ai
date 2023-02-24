# frozen_string_literal: true

module ::DiscourseAI
  class ChatMessageClassification < Classification
    private

    def store_classification(chat_message, type, classification_data)
      PluginStore.set(
        type,
        "chat_message_#{chat_message.id}",
        classification_data.merge(date: Time.now.utc),
      )
    end

    def flag!(chat_message, _toxic_labels)
      Chat::ChatReviewQueue.new.flag_message(
        chat_message,
        Guardian.new(flagger),
        ReviewableScore.types[:inappropriate],
        queue_for_review: true,
      )
    end
  end
end
