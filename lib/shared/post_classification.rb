# frozen_string_literal: true

module ::DiscourseAI
  class PostClassification < Classification
    private

    def flag!(post, classification_type)
      PostActionCreator.new(
        flagger,
        post,
        PostActionType.types[:inappropriate],
        reason: classification_type,
        queue_for_review: true,
      ).perform

      post.publish_change_to_clients! :acted
    end
  end
end
