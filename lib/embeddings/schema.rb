# frozen_string_literal: true

# We don't have AR objects for our embeddings, so this class
# acts as an intermediary between us and the DB.
# It lets us retrieve embeddings either symmetrically and asymmetrically,
# and also store them.

module DiscourseAi
  module Embeddings
    class Schema
      TOPICS_TABLE = "ai_topic_embeddings"
      POSTS_TABLE = "ai_post_embeddings"
      RAG_DOCS_TABLE = "ai_document_fragment_embeddings"

      def self.for(
        target_klass,
        vector: DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation
      )
        case target_klass&.name
        when "Topic"
          new(TOPICS_TABLE, "topic_id", vector)
        when "Post"
          new(POSTS_TABLE, "post_id", vector)
        when "RagDocumentFragment"
          new(RAG_DOCS_TABLE, "rag_document_fragment_id", vector)
        else
          raise ArgumentError, "Invalid target type for embeddings"
        end
      end

      def initialize(table, target_column, vector)
        @table = table
        @target_column = target_column
        @vector = vector
      end

      attr_reader :table, :target_column, :vector

      def find_by_embedding(embedding)
        DB.query(<<~SQL, query_embedding: embedding, vid: vector.id, vsid: vector.strategy_id).first
          SELECT *
          FROM #{table}
          WHERE
            model_id = :vid AND strategy_id = :vsid
          ORDER BY
            embeddings::halfvec(#{dimensions}) #{pg_function} '[:query_embedding]'::halfvec(#{dimensions})
          LIMIT 1
        SQL
      end

      def find_by_target(target)
        DB.query(<<~SQL, target_id: target.id, vid: vector.id, vsid: vector.strategy_id).first
          SELECT *
          FROM #{table}
          WHERE
            model_id = :vid AND
            strategy_id = :vsid AND
            #{target_column} = :target_id
          LIMIT 1
        SQL
      end

      def asymmetric_similarity_search(embedding, limit:, offset:)
        builder = DB.build(<<~SQL)
          WITH candidates AS (
            SELECT
              #{target_column},
              embeddings::halfvec(#{dimensions}) AS embeddings
            FROM
              #{table}
            /*join*/
            /*where*/
            ORDER BY
              binary_quantize(embeddings)::bit(#{dimensions}) <~> binary_quantize('[:query_embedding]'::halfvec(#{dimensions}))
            LIMIT :limit * 2
          )
          SELECT
            #{target_column},
            embeddings::halfvec(#{dimensions}) #{pg_function} '[:query_embedding]'::halfvec(#{dimensions}) AS distance
          FROM
            candidates
          ORDER BY
            embeddings::halfvec(#{dimensions}) #{pg_function} '[:query_embedding]'::halfvec(#{dimensions})
          LIMIT :limit
          OFFSET :offset
        SQL

        builder.where(
          "model_id = :model_id AND strategy_id = :strategy_id",
          model_id: vector.id,
          strategy_id: vector.strategy_id,
        )

        yield(builder) if block_given?

        builder.query(query_embedding: embedding, limit: limit, offset: offset)
      rescue PG::Error => e
        Rails.logger.error("Error #{e} querying embeddings for model #{name}")
        raise MissingEmbeddingError
      end

      def symmetric_similarity_search(record)
        builder = DB.build(<<~SQL)
          WITH le_target AS (
            SELECT
              embeddings
            FROM
              #{table}
            WHERE
              model_id = :vid AND
              strategy_id = :vsid AND
              #{target_column} = :target_id
            LIMIT 1
          )
          SELECT #{target_column} FROM (
            SELECT
              #{target_column}, embeddings
            FROM
              #{table}
            /*join*/
            /*where*/
            ORDER BY
              binary_quantize(embeddings)::bit(#{dimensions}) <~> (
                SELECT
                  binary_quantize(embeddings)::bit(#{dimensions})
                FROM
                  le_target
                LIMIT 1
              )
            LIMIT 200
          ) AS widenet
          ORDER BY
            embeddings::halfvec(#{dimensions}) #{pg_function} (
              SELECT
                embeddings::halfvec(#{dimensions})
              FROM
                le_target
              LIMIT 1
            )
          LIMIT 100;
        SQL

        builder.where("model_id = :vid AND strategy_id = :vsid")

        yield(builder) if block_given?

        builder.query(vid: vector.id, vsid: vector.strategy_id, target_id: record.id)
      rescue PG::Error => e
        Rails.logger.error("Error #{e} querying embeddings for model #{name}")
        raise MissingEmbeddingError
      end

      def store(record, embedding, digest)
        DB.exec(
          <<~SQL,
          INSERT INTO #{table} (#{target_column}, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
          VALUES (:target_id, :model_id, :model_version, :strategy_id, :strategy_version, :digest, '[:embeddings]', :now, :now)
          ON CONFLICT (model_id, strategy_id, #{target_column})
          DO UPDATE SET
            model_version = :model_version,
            strategy_version = :strategy_version,
            digest = :digest,
            embeddings = '[:embeddings]',
            updated_at = :now
          SQL
          target_id: record.id,
          model_id: vector.id,
          model_version: vector.version,
          strategy_id: vector.strategy_id,
          strategy_version: vector.strategy_version,
          digest: digest,
          embeddings: embedding,
          now: Time.zone.now,
        )
      end

      private

      delegate :dimensions, :pg_function, to: :vector
    end
  end
end
