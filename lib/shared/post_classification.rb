# frozen_string_literal: true

module ::DiscourseAI
  class PostClassification < Classification
    private

    def store_classification(post, type, classification_data)
      PostCustomField.create!(post_id: post.id, name: type, value: classification_data.to_json)
    end

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
