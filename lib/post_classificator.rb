# frozen_string_literal: true

module ::DiscourseAi
  class PostClassificator < Classificator
    private

    def flag!(post, classification, verdicts, accuracies)
      post.hide!(ReviewableScore.types[:inappropriate])

      reviewable =
        ReviewableAiPost.needs_review!(
          created_by: Discourse.system_user,
          target: post,
          reviewable_by_moderator: true,
          potential_spam: false,
          payload: {
            classification: classification,
            accuracies: accuracies,
            verdicts: verdicts,
          },
        )

      add_score(reviewable)
    end
  end
end
