# frozen_string_literal: true

module ::DiscourseAi
  class ChatMessageClassificator < Classificator
    private

    def flag!(chat_message, classification, verdicts, accuracies)
      reviewable =
        ReviewableAiChatMessage.needs_review!(
          created_by: Discourse.system_user,
          target: chat_message,
          reviewable_by_moderator: true,
          potential_spam: false,
          payload: {
            classification: classification,
            accuracies: accuracies,
            verdicts: verdicts,
          },
        )
      reviewable.update(target_created_by: chat_message.user)

      add_score(reviewable)
    end
  end
end
