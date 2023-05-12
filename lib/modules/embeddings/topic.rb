# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    class Topic
      VERSION = 1

      def generate_and_store_embeddings_for(topic, include_posts: true)
        return unless SiteSetting.ai_embeddings_enabled
        return if topic.blank? || topic.first_post.blank?

        enabled_models = DiscourseAi::Embeddings::Model.enabled_models
        return if enabled_models.empty?

        enabled_models.each do |model|
          embedding = model.generate_embedding(topic.first_post.raw)
          persist_embedding(topic, model, embedding) if embedding

          if include_posts
            persist_embedding(topic.first_post, model, embedding) if embedding

            topic
              .posts
              .where("post_number > 1 AND post_type = 1")
              .each do |post|
                embedding = model.generate_embedding(post.raw)
                persist_embedding(post, model, embedding) if embedding
              end
          end
        end
      end

      def symmetric_semantic_search(model, topic)
        candidate_ids =
          DiscourseAi::Database::Connection.db.query(<<~SQL, topic_id: topic.id).map(&:topic_id)
          SELECT
            topic_id
          FROM
            topic_embeddings_#{model.name.underscore}
          ORDER BY
            embedding #{model.pg_function} (
              SELECT
                embedding
              FROM
                topic_embeddings_#{model.name.underscore}
              WHERE
                topic_id = :topic_id
              LIMIT 1
            )
          LIMIT 100
        SQL

        # Happens when the topic doesn't have any embeddings
        # I'd rather not use Exceptions to control the flow, so this should be refactored soon
        if candidate_ids.empty? || !candidate_ids.include?(topic.id)
          raise StandardError, "No embeddings found for topic #{topic.id}"
        end

        candidate_ids
      end

      def asymmetric_semantic_search(model, query, limit, offset)
        embedding = model.generate_embedding(query)

        candidate_ids =
          DiscourseAi::Database::Connection
            .db
            .query(<<~SQL, query_embedding: embedding, limit: limit, offset: offset)
          SELECT
            topic_id
          FROM
            topic_embeddings_#{model.name.underscore}
          ORDER BY
            embedding #{model.pg_function} '[:query_embedding]'
          LIMIT :limit
          OFFSET :offset
        SQL
            .map(&:topic_id)

        raise StandardError, "No embeddings found for topic #{topic.id}" if candidate_ids.empty?

        candidate_ids
      end

      private

      def persist_embedding(topic_or_post, model, embedding)
        table = topic_or_post.is_a?(Topic) ? "topic" : "post"

        DiscourseAi::Database::Connection.db.exec(
          <<~SQL,
            INSERT INTO #{table}_embeddings_#{model.name.underscore} (#{table}_id, embedding, version)
            VALUES (:id, '[:embedding]', :version)
            ON CONFLICT (#{table}_id)
            DO UPDATE SET embedding = '[:embedding]'
          SQL
          id: topic_or_post.id,
          embedding: embedding,
          version: VERSION,
        )
      end
    end
  end
end
