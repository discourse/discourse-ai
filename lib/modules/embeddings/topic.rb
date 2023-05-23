# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    MissingEmbeddingError = Class.new(StandardError)

    class Topic
      def generate_and_store_embeddings_for(topic)
        return unless SiteSetting.ai_embeddings_enabled
        return if topic.blank? || topic.first_post.blank?

        enabled_models = DiscourseAi::Embeddings::Model.enabled_models
        return if enabled_models.empty?

        enabled_models.each do |model|
          embedding = model.generate_embedding(topic.first_post.raw)
          persist_embedding(topic, model, embedding) if embedding
        end
      end

      def symmetric_semantic_search(model, topic)
        candidate_ids = query_symmetric_embeddings(model, topic)

        # Happens when the topic doesn't have any embeddings
        # I'd rather not use Exceptions to control the flow, so this should be refactored soon
        if candidate_ids.empty? || !candidate_ids.include?(topic.id)
          raise MissingEmbeddingError, "No embeddings found for topic #{topic.id}"
        end

        candidate_ids
      end

      def asymmetric_semantic_search(model, query, limit, offset)
        embedding = model.generate_embedding(query)

        begin
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
        rescue PG::Error => e
          raise StandardError, "No embeddings found for topic #{topic.id}" if candidate_ids.empty?
        end

        candidate_ids
      end

      private

      def query_symmetric_embeddings(model, topic)
        begin
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
        rescue PG::Error => e
          Rails.logger.error(
            "Error #{e} querying embeddings for topic #{topic.id} and model #{model.name}",
          )
        end
      end

      def persist_embedding(topic, model, embedding)
        begin
          DiscourseAi::Database::Connection.db.exec(
            <<~SQL,
              INSERT INTO topic_embeddings_#{model.name.underscore} (topic_id, embedding)
              VALUES (:topic_id, '[:embedding]')
              ON CONFLICT (topic_id)
              DO UPDATE SET embedding = '[:embedding]'
            SQL
            topic_id: topic.id,
            embedding: embedding,
          )
        rescue PG::Error => e
          Rails.logger.error(
            "Error #{e} persisting embedding for topic #{topic.id} and model #{model.name}",
          )
        end
      end
    end
  end
end
