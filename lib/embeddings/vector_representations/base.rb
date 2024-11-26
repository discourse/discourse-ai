# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module VectorRepresentations
      class Base
        class << self
          def find_representation(model_name)
            # we are explicit here cause the loader may have not
            # loaded the subclasses yet
            [
              DiscourseAi::Embeddings::VectorRepresentations::AllMpnetBaseV2,
              DiscourseAi::Embeddings::VectorRepresentations::BgeLargeEn,
              DiscourseAi::Embeddings::VectorRepresentations::BgeM3,
              DiscourseAi::Embeddings::VectorRepresentations::Gemini,
              DiscourseAi::Embeddings::VectorRepresentations::MultilingualE5Large,
              DiscourseAi::Embeddings::VectorRepresentations::TextEmbedding3Large,
              DiscourseAi::Embeddings::VectorRepresentations::TextEmbedding3Small,
              DiscourseAi::Embeddings::VectorRepresentations::TextEmbeddingAda002,
            ].find { _1.name == model_name }
          end

          def current_representation(strategy)
            find_representation(SiteSetting.ai_embeddings_model).new(strategy)
          end

          def correctly_configured?
            raise NotImplementedError
          end

          def dependant_setting_names
            raise NotImplementedError
          end

          def configuration_hint
            settings = dependant_setting_names
            I18n.t(
              "discourse_ai.embeddings.configuration.hint",
              settings: settings.join(", "),
              count: settings.length,
            )
          end
        end

        def initialize(strategy)
          @strategy = strategy
        end

        def vector_from(text, asymetric: false)
          raise NotImplementedError
        end

        def gen_bulk_reprensentations(relation)
          http_pool_size = 100
          pool =
            Concurrent::CachedThreadPool.new(
              min_threads: 0,
              max_threads: http_pool_size,
              idletime: 30,
            )

          embedding_gen = inference_client
          promised_embeddings =
            relation
              .map do |record|
                prepared_text = prepare_text(record)
                next if prepared_text.blank?

                Concurrent::Promises
                  .fulfilled_future({ target: record, text: prepared_text }, pool)
                  .then_on(pool) do |w_prepared_text|
                    w_prepared_text.merge(
                      embedding: embedding_gen.perform!(w_prepared_text[:text]),
                      digest: OpenSSL::Digest::SHA1.hexdigest(w_prepared_text[:text]),
                    )
                  end
              end
              .compact

          Concurrent::Promises
            .zip(*promised_embeddings)
            .value!
            .each { |e| save_to_db(e[:target], e[:embedding], e[:digest]) }
        end

        def generate_representation_from(target, persist: true)
          text = prepare_text(target)
          return if text.blank?

          target_column =
            case target
            when Topic
              "topic_id"
            when Post
              "post_id"
            when RagDocumentFragment
              "rag_document_fragment_id"
            else
              raise ArgumentError, "Invalid target type"
            end

          new_digest = OpenSSL::Digest::SHA1.hexdigest(text)
          current_digest = DB.query_single(<<~SQL, target_id: target.id).first
            SELECT
              digest
            FROM
              #{table_name(target)}
            WHERE
              model_id = #{id} AND
              strategy_id = #{@strategy.id} AND
              #{target_column} = :target_id
            LIMIT 1
          SQL
          return if current_digest == new_digest

          vector = vector_from(text)

          save_to_db(target, vector, new_digest) if persist
        end

        def topic_id_from_representation(raw_vector)
          DB.query_single(<<~SQL, query_embedding: raw_vector).first
            SELECT
              topic_id
            FROM
              #{topic_table_name}
            WHERE
              model_id = #{id} AND
              strategy_id = #{@strategy.id}
            ORDER BY
              embeddings::halfvec(#{dimensions}) #{pg_function} '[:query_embedding]'::halfvec(#{dimensions})
            LIMIT 1
          SQL
        end

        def post_id_from_representation(raw_vector)
          DB.query_single(<<~SQL, query_embedding: raw_vector).first
            SELECT
              post_id
            FROM
              #{post_table_name}
            WHERE
              model_id = #{id} AND
              strategy_id = #{@strategy.id}
            ORDER BY
              embeddings::halfvec(#{dimensions}) #{pg_function} '[:query_embedding]'::halfvec(#{dimensions})
            LIMIT 1
          SQL
        end

        def asymmetric_topics_similarity_search(raw_vector, limit:, offset:, return_distance: false)
          results = DB.query(<<~SQL, query_embedding: raw_vector, limit: limit, offset: offset)
            WITH candidates AS (
              SELECT
                topic_id,
                embeddings::halfvec(#{dimensions}) AS embeddings
              FROM
                #{topic_table_name}
              WHERE
                model_id = #{id} AND strategy_id = #{@strategy.id}
              ORDER BY
                binary_quantize(embeddings)::bit(#{dimensions}) <~> binary_quantize('[:query_embedding]'::halfvec(#{dimensions}))
              LIMIT :limit * 2
            )
            SELECT
              topic_id,
              embeddings::halfvec(#{dimensions}) #{pg_function} '[:query_embedding]'::halfvec(#{dimensions}) AS distance
            FROM
              candidates
            ORDER BY
              embeddings::halfvec(#{dimensions}) #{pg_function} '[:query_embedding]'::halfvec(#{dimensions})
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

        def asymmetric_posts_similarity_search(raw_vector, limit:, offset:, return_distance: false)
          results = DB.query(<<~SQL, query_embedding: raw_vector, limit: limit, offset: offset)
            WITH candidates AS (
              SELECT
                post_id,
                embeddings::halfvec(#{dimensions}) AS embeddings
              FROM
                #{post_table_name}
              WHERE
                model_id = #{id} AND strategy_id = #{@strategy.id}
              ORDER BY
                binary_quantize(embeddings)::bit(#{dimensions}) <~> binary_quantize('[:query_embedding]'::halfvec(#{dimensions}))
              LIMIT :limit * 2
            )
            SELECT
              post_id,
              embeddings::halfvec(#{dimensions}) #{pg_function} '[:query_embedding]'::halfvec(#{dimensions}) AS distance
            FROM
              candidates
            ORDER BY
              embeddings::halfvec(#{dimensions}) #{pg_function} '[:query_embedding]'::halfvec(#{dimensions})
            LIMIT :limit
            OFFSET :offset
          SQL

          if return_distance
            results.map { |r| [r.post_id, r.distance] }
          else
            results.map(&:post_id)
          end
        rescue PG::Error => e
          Rails.logger.error("Error #{e} querying embeddings for model #{name}")
          raise MissingEmbeddingError
        end

        def asymmetric_rag_fragment_similarity_search(
          raw_vector,
          target_id:,
          target_type:,
          limit:,
          offset:,
          return_distance: false
        )
          # A too low limit exacerbates the the recall loss of binary quantization
          binary_search_limit = [limit * 2, 100].max
          results =
            DB.query(
              <<~SQL,
                WITH candidates AS (
                  SELECT
                    rag_document_fragment_id,
                    embeddings::halfvec(#{dimensions}) AS embeddings
                  FROM
                    #{rag_fragments_table_name}
                  INNER JOIN
                    rag_document_fragments ON
                      rag_document_fragments.id = rag_document_fragment_id AND
                      rag_document_fragments.target_id = :target_id AND
                      rag_document_fragments.target_type = :target_type
                  WHERE
                    model_id = #{id} AND strategy_id = #{@strategy.id}
                  ORDER BY
                    binary_quantize(embeddings)::bit(#{dimensions}) <~> binary_quantize('[:query_embedding]'::halfvec(#{dimensions}))
                  LIMIT :binary_search_limit
                )
                SELECT
                  rag_document_fragment_id,
                  embeddings::halfvec(#{dimensions}) #{pg_function} '[:query_embedding]'::halfvec(#{dimensions}) AS distance
                FROM
                  candidates
                ORDER BY
                  embeddings::halfvec(#{dimensions}) #{pg_function} '[:query_embedding]'::halfvec(#{dimensions})
                LIMIT :limit
                OFFSET :offset
              SQL
              query_embedding: raw_vector,
              target_id: target_id,
              target_type: target_type,
              limit: limit,
              offset: offset,
              binary_search_limit: binary_search_limit,
            )

          if return_distance
            results.map { |r| [r.rag_document_fragment_id, r.distance] }
          else
            results.map(&:rag_document_fragment_id)
          end
        rescue PG::Error => e
          Rails.logger.error("Error #{e} querying embeddings for model #{name}")
          raise MissingEmbeddingError
        end

        def symmetric_topics_similarity_search(topic)
          DB.query(<<~SQL, topic_id: topic.id).map(&:topic_id)
            WITH le_target AS (
              SELECT
                  embeddings
                FROM
                  #{topic_table_name}
                WHERE
                  model_id = #{id} AND
                  strategy_id = #{@strategy.id} AND
                  topic_id = :topic_id
                LIMIT 1
            )
            SELECT topic_id FROM (
              SELECT
                topic_id, embeddings
              FROM
                #{topic_table_name}
              WHERE
                model_id = #{id} AND
                strategy_id = #{@strategy.id}
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
        rescue PG::Error => e
          Rails.logger.error(
            "Error #{e} querying embeddings for topic #{topic.id} and model #{name}",
          )
          raise MissingEmbeddingError
        end

        def topic_table_name
          "ai_topic_embeddings"
        end

        def post_table_name
          "ai_post_embeddings"
        end

        def rag_fragments_table_name
          "ai_document_fragment_embeddings"
        end

        def table_name(target)
          case target
          when Topic
            topic_table_name
          when Post
            post_table_name
          when RagDocumentFragment
            rag_fragments_table_name
          else
            raise ArgumentError, "Invalid target type"
          end
        end

        def index_name(table_name)
          "#{table_name}_#{id}_#{@strategy.id}_search"
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

        def asymmetric_query_prefix
          raise NotImplementedError
        end

        protected

        def save_to_db(target, vector, digest)
          if target.is_a?(Topic)
            DB.exec(
              <<~SQL,
              INSERT INTO #{topic_table_name} (topic_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
              VALUES (:topic_id, :model_id, :model_version, :strategy_id, :strategy_version, :digest, '[:embeddings]', :now, :now)
              ON CONFLICT (strategy_id, model_id, topic_id)
              DO UPDATE SET
                model_version = :model_version,
                strategy_version = :strategy_version,
                digest = :digest,
                embeddings = '[:embeddings]',
                updated_at = :now
              SQL
              topic_id: target.id,
              model_id: id,
              model_version: version,
              strategy_id: @strategy.id,
              strategy_version: @strategy.version,
              digest: digest,
              embeddings: vector,
              now: Time.zone.now,
            )
          elsif target.is_a?(Post)
            DB.exec(
              <<~SQL,
              INSERT INTO #{post_table_name} (post_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
              VALUES (:post_id, :model_id, :model_version, :strategy_id, :strategy_version, :digest, '[:embeddings]', :now, :now)
              ON CONFLICT (model_id, strategy_id, post_id)
              DO UPDATE SET
                model_version = :model_version,
                strategy_version = :strategy_version,
                digest = :digest,
                embeddings = '[:embeddings]',
                updated_at = :now
              SQL
              post_id: target.id,
              model_id: id,
              model_version: version,
              strategy_id: @strategy.id,
              strategy_version: @strategy.version,
              digest: digest,
              embeddings: vector,
              now: Time.zone.now,
            )
          elsif target.is_a?(RagDocumentFragment)
            DB.exec(
              <<~SQL,
              INSERT INTO #{rag_fragments_table_name} (rag_document_fragment_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
              VALUES (:fragment_id, :model_id, :model_version, :strategy_id, :strategy_version, :digest, '[:embeddings]', :now, :now)
              ON CONFLICT (model_id, strategy_id, rag_document_fragment_id)
              DO UPDATE SET
                model_version = :model_version,
                strategy_version = :strategy_version,
                digest = :digest,
                embeddings = '[:embeddings]',
                updated_at = :now
              SQL
              fragment_id: target.id,
              model_id: id,
              model_version: version,
              strategy_id: @strategy.id,
              strategy_version: @strategy.version,
              digest: digest,
              embeddings: vector,
              now: Time.zone.now,
            )
          else
            raise ArgumentError, "Invalid target type"
          end
        end

        def inference_client
          raise NotImplementedError
        end

        def prepare_text(record)
          @strategy.prepare_text_from(record, tokenizer, max_sequence_length - 2)
        end
      end
    end
  end
end
