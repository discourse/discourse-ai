# frozen_string_literal: true

module ::DiscourseAI
  class PostClassificator < Classificator
    private

    def flag!(post, classification)
      post.hide!(ReviewableScore.types[:inappropriate])

      reviewable =
        ReviewableAIPost.needs_review!(
          created_by: Discourse.system_user,
          target: post,
          reviewable_by_moderator: true,
          potential_spam: false,
          payload: {
            classification: classification,
          },
        )

      add_score(reviewable)
    end
  end
end
