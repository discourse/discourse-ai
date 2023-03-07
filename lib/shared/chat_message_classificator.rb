# frozen_string_literal: true

module ::DiscourseAI
  class ChatMessageClassificator < Classificator
    private

    def flag!(chat_message, toxic_labels)
      reviewable =
        ReviewableAIChatMessage.needs_review!(
          created_by: Discourse.system_user,
          target: chat_message,
          reviewable_by_moderator: true,
          potential_spam: false,
          payload: toxic_labels,
        )
      reviewable.update(target_created_by: chat_message.user)

      add_score(reviewable)
    end
  end
end
