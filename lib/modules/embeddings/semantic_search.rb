# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    class SemanticSearch
      def initialize(guardian, model)
        @guardian = guardian
        @model = model
      end

      def search_for_topics(query, page = 1)
        limit = Search.per_filter + 1
        offset = (page - 1) * Search.per_filter

        candidate_ids =
          DiscourseAi::Embeddings::Topic.new.asymmetric_semantic_search(model, query, limit, offset)

        ::Post
          .where(post_type: ::Topic.visible_post_types(guardian.user))
          .public_posts
          .where("topics.visible")
          .where(topic_id: candidate_ids, post_number: 1)
          .order("array_position(ARRAY#{candidate_ids}, topic_id)")
      end

      private

      attr_reader :model, :guardian
    end
  end
end
