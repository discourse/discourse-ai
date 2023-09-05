# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module VectorRepresentations
      class Base
        def self.current_representation(strategy)
          subclasses.map { _1.new(strategy) }.find { _1.name == SiteSetting.ai_embeddings_model }
        end

        def initialize(strategy)
          @strategy = strategy
        end

        def create_index(lists, probes)
          index_name = "#{table_name}_search"

          DB.exec(<<~SQL)
            DROP INDEX IF EXISTS #{index_name};
            CREATE INDEX IF NOT EXISTS
              #{index}
            ON
              #{table_name}
            USING
              ivfflat (embeddings #{pg_index_type})
            WITH
              (lists = #{lists})
            WHERE
              model_version = #{version} AND
              strategy_version = #{@strategy.version};
            SQL
        end

        def vector_from(text)
          raise NotImplementedError
        end

        def generate_topic_representation_from(target, persist: true)
          text = @strategy.prepare_text_from(target, tokenizer, max_sequence_length - 2)

          vector_from(text).tap do |vector|
            if persist
              digest = OpenSSL::Digest::SHA1.hexdigest(text)
              save_to_db(target, vector, digest)
            end
          end
        end

        def topic_id_from_representation(raw_vector)
          DB.query_single(<<~SQL, query_embedding: raw_vector).first
            SELECT
              topic_id
            FROM
              #{table_name}
            ORDER BY
              embeddings #{pg_function} '[:query_embedding]'
            LIMIT 1
          SQL
        end

        def asymmetric_topics_similarity_search(raw_vector, limit:, offset:, return_distance: false)
          results = DB.query(<<~SQL, query_embedding: raw_vector, limit: limit, offset: offset)
            SELECT
              topic_id,
              embeddings #{pg_function} '[:query_embedding]' AS distance
            FROM
              #{table_name}
            ORDER BY
              embeddings #{pg_function} '[:query_embedding]'
            LIMIT :limit
            OFFSET :offset
          SQL

          if return_distance
            results.map { |r| [r.topic_id, r.distance] }
          else
            results.map(&:topic_id)
          end
        rescue PG::Error => e
          Rails.logger.error("Error #{e} querying embeddings for model #{name}")
          raise MissingEmbeddingError
        end

        def symmetric_topics_similarity_search(topic)
          DB.query(<<~SQL, topic_id: topic.id).map(&:topic_id)
            SELECT
              topic_id
            FROM
              #{table_name}
            ORDER BY
              embeddings #{pg_function} (
                SELECT
                  embeddings
                FROM
                  #{table_name}
                WHERE
                  topic_id = :topic_id
                LIMIT 1
              )
            LIMIT 100
          SQL
        rescue PG::Error => e
          Rails.logger.error(
            "Error #{e} querying embeddings for topic #{topic.id} and model #{name}",
          )
          raise MissingEmbeddingError
        end

        def table_name
          "ai_topic_embeddings_#{id}_#{@strategy.id}"
        end

        def name
          raise NotImplementedError
        end

        def dimensions
          raise NotImplementedError
        end

        def max_sequence_length
          raise NotImplementedError
        end

        def id
          raise NotImplementedError
        end

        def pg_function
          raise NotImplementedError
        end

        def version
          raise NotImplementedError
        end

        def tokenizer
          raise NotImplementedError
        end

        protected

        def save_to_db(target, vector, digest)
          DB.exec(
            <<~SQL,
            INSERT INTO #{table_name} (topic_id, model_version, strategy_version, digest, embeddings, created_at, updated_at)
            VALUES (:topic_id, :model_version, :strategy_version, :digest, '[:embeddings]', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            ON CONFLICT (topic_id)
            DO UPDATE SET
              model_version = :model_version,
              strategy_version = :strategy_version,
              digest = :digest,
              embeddings = '[:embeddings]',
              updated_at = CURRENT_TIMESTAMP
            SQL
            topic_id: target.id,
            model_version: version,
            strategy_version: @strategy.version,
            digest: digest,
            embeddings: vector,
          )
        end
      end
    end
  end
end
