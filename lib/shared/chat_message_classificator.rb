# frozen_string_literal: true

module ::DiscourseAI
  class ChatMessageClassificator < Classificator
    private

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
