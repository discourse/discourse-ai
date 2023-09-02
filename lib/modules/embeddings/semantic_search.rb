# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    class SemanticSearch
      def initialize(guardian)
        @guardian = guardian
        @manager = DiscourseAi::Embeddings::Manager.new(nil)
        @model = @manager.model
      end

      def search_for_topics(query, page = 1)
        limit = Search.per_filter + 1
        offset = (page - 1) * Search.per_filter

        candidate_ids = asymmetric_semantic_search(query, limit, offset)

        ::Post
          .where(post_type: ::Topic.visible_post_types(guardian.user))
          .public_posts
          .where("topics.visible")
          .where(topic_id: candidate_ids, post_number: 1)
          .order("array_position(ARRAY#{candidate_ids}, topic_id)")
      end

      def asymmetric_semantic_search(query, limit, offset, return_distance: false)
        embedding = model.generate_embeddings(query)
        table = @manager.topic_embeddings_table

        begin
          candidate_ids = DB.query(<<~SQL, query_embedding: embedding, limit: limit, offset: offset)
                SELECT
                  topic_id,
                  embeddings #{@model.pg_function} '[:query_embedding]' AS distance
                FROM
                  #{table}
                ORDER BY
                  embeddings #{@model.pg_function} '[:query_embedding]'
                LIMIT :limit
                OFFSET :offset
              SQL
        rescue PG::Error => e
          Rails.logger.error(
            "Error #{e} querying embeddings for model #{model.name} and search #{query}",
          )
          raise MissingEmbeddingError
        end

        if return_distance
          candidate_ids.map { |c| [c.topic_id, c.distance] }
        else
          candidate_ids.map(&:topic_id)
        end
      end

      private

      attr_reader :model, :guardian
    end
  end
end
