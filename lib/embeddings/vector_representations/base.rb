# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module VectorRepresentations
      class Base
        def self.current_representation(strategy)
          # we are explicit here cause the loader may have not
          # loaded the subclasses yet
          [
            DiscourseAi::Embeddings::VectorRepresentations::AllMpnetBaseV2,
            DiscourseAi::Embeddings::VectorRepresentations::BgeLargeEn,
            DiscourseAi::Embeddings::VectorRepresentations::MultilingualE5Large,
            DiscourseAi::Embeddings::VectorRepresentations::TextEmbeddingAda002,
          ].map { _1.new(strategy) }.find { _1.name == SiteSetting.ai_embeddings_model }
        end

        def initialize(strategy)
          @strategy = strategy
        end

        def consider_indexing(memory: "100MB")
          # Using extension maintainer's recommendation for ivfflat indexes
          # Results are not as good as without indexes, but it's much faster
          # Disk usage is ~1x the size of the table, so this doubles table total size
          count = DB.query_single("SELECT count(*) FROM #{table_name};").first
          lists = [count < 1_000_000 ? count / 1000 : Math.sqrt(count).to_i, 10].max
          probes = [count < 1_000_000 ? lists / 10 : Math.sqrt(lists).to_i, 1].max

          existing_index = DB.query_single(<<~SQL, index_name: index_name).first
            SELECT
              indexdef
            FROM
              pg_indexes
            WHERE
              indexname = :index_name
            LIMIT 1
          SQL

          if !existing_index.present?
            Rails.logger.info("Index #{index_name} does not exist, creating...")
            return create_index!(memory, lists, probes)
          end

          existing_index_age =
            DB
              .query_single(
                "SELECT pg_catalog.obj_description((:index_name)::regclass, 'pg_class');",
                index_name: index_name,
              )
              .first
              .to_i || 0
          new_rows =
            DB.query_single(
              "SELECT count(*) FROM #{table_name} WHERE created_at > '#{Time.at(existing_index_age)}';",
            ).first
          existing_lists = existing_index.match(/lists='(\d+)'/)&.captures&.first&.to_i

          if existing_index_age > 0 && existing_index_age < 1.hour.ago.to_i
            if new_rows > 10_000
              Rails.logger.info(
                "Index #{index_name} is #{existing_index_age} seconds old, and there are #{new_rows} new rows, updating...",
              )
              return create_index!(memory, lists, probes)
            elsif existing_lists != lists
              Rails.logger.info(
                "Index #{index_name} already exists, but lists is #{existing_lists} instead of #{lists}, updating...",
              )
              return create_index!(memory, lists, probes)
            end
          end

          Rails.logger.info(
            "Index #{index_name} kept. #{Time.now.to_i - existing_index_age} seconds old, #{new_rows} new rows, #{existing_lists} lists, #{probes} probes.",
          )
        end

        def create_index!(memory, lists, probes)
          DB.exec("SET work_mem TO '#{memory}';")
          DB.exec("SET maintenance_work_mem TO '#{memory}';")
          DB.exec(<<~SQL)
            DROP INDEX IF EXISTS #{index_name};
            CREATE INDEX IF NOT EXISTS
              #{index_name}
            ON
              #{table_name}
            USING
              ivfflat (embeddings #{pg_index_type})
            WITH
              (lists = #{lists});
          SQL
          DB.exec("COMMENT ON INDEX #{index_name} IS '#{Time.now.to_i}';")
          DB.exec("RESET work_mem;")
          DB.exec("RESET maintenance_work_mem;")

          database = DB.query_single("SELECT current_database();").first
          DB.exec("ALTER DATABASE #{database} SET ivfflat.probes = #{probes};")
        end

        def vector_from(text)
          raise NotImplementedError
        end

        def generate_topic_representation_from(target, persist: true)
          text = @strategy.prepare_text_from(target, tokenizer, max_sequence_length - 2)

          new_digest = OpenSSL::Digest::SHA1.hexdigest(text)
          current_digest = DB.query_single(<<~SQL, topic_id: target.id).first
            SELECT
              digest
            FROM
              #{table_name}
            WHERE
              topic_id = :topic_id
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

        def index_name
          "#{table_name}_search"
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
