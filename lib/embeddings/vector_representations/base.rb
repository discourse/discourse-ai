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
              DiscourseAi::Embeddings::VectorRepresentations::Gemini,
              DiscourseAi::Embeddings::VectorRepresentations::MultilingualE5Large,
              DiscourseAi::Embeddings::VectorRepresentations::TextEmbeddingAda002,
              DiscourseAi::Embeddings::VectorRepresentations::TextEmbedding3Small,
              DiscourseAi::Embeddings::VectorRepresentations::TextEmbedding3Large,
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

        def consider_indexing(memory: "100MB")
          [topic_table_name, post_table_name].each do |table_name|
            index_name = index_name(table_name)
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
                AND schemaname = 'public'
              LIMIT 1
            SQL

            if !existing_index.present?
              Rails.logger.info("Index #{index_name} does not exist, creating...")
              return create_index!(table_name, memory, lists, probes)
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

            if existing_index_age > 0 &&
                 existing_index_age <
                   (
                     if SiteSetting.ai_embeddings_semantic_related_topics_enabled
                       1.hour.ago.to_i
                     else
                       1.day.ago.to_i
                     end
                   )
              if new_rows > 10_000
                Rails.logger.info(
                  "Index #{index_name} is #{existing_index_age} seconds old, and there are #{new_rows} new rows, updating...",
                )
                return create_index!(table_name, memory, lists, probes)
              elsif existing_lists != lists
                Rails.logger.info(
                  "Index #{index_name} already exists, but lists is #{existing_lists} instead of #{lists}, updating...",
                )
                return create_index!(table_name, memory, lists, probes)
              end
            end

            Rails.logger.info(
              "Index #{index_name} kept. #{Time.now.to_i - existing_index_age} seconds old, #{new_rows} new rows, #{existing_lists} lists, #{probes} probes.",
            )
          end
        end

        def create_index!(table_name, memory, lists, probes)
          tries = 0
          index_name = index_name(table_name)
          DB.exec("SET work_mem TO '#{memory}';")
          DB.exec("SET maintenance_work_mem TO '#{memory}';")
          begin
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
          rescue PG::ProgramLimitExceeded => e
            parsed_error = e.message.match(/memory required is (\d+ [A-Z]{2}), ([a-z_]+)/)
            if parsed_error[1].present? && parsed_error[2].present?
              DB.exec("SET #{parsed_error[2]} TO '#{parsed_error[1].tr(" ", "")}';")
              tries += 1
              retry if tries < 3
            else
              raise e
            end
          end

          DB.exec("COMMENT ON INDEX #{index_name} IS '#{Time.now.to_i}';")
          DB.exec("RESET work_mem;")
          DB.exec("RESET maintenance_work_mem;")

          database = DB.query_single("SELECT current_database();").first

          # This is a global setting, if we set it based on post count
          # we will be unable to use the index for topics
          # Hopefully https://github.com/pgvector/pgvector/issues/235 will make this better
          if table_name == topic_table_name
            DB.exec("ALTER DATABASE #{database} SET ivfflat.probes = #{probes};")
          end
        end

        def vector_from(text)
          raise NotImplementedError
        end

        def generate_representation_from(target, persist: true)
          text = @strategy.prepare_text_from(target, tokenizer, max_sequence_length - 2)
          return if text.blank?

          new_digest = OpenSSL::Digest::SHA1.hexdigest(text)
          current_digest = DB.query_single(<<~SQL, target_id: target.id).first
            SELECT
              digest
            FROM
              #{table_name(target)}
            WHERE
              #{target.is_a?(Topic) ? "topic_id" : "post_id"} = :target_id
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
            ORDER BY
              embeddings #{pg_function} '[:query_embedding]'
            LIMIT 1
          SQL
        end

        def post_id_from_representation(raw_vector)
          DB.query_single(<<~SQL, query_embedding: raw_vector).first
            SELECT
              post_id
            FROM
              #{post_table_name}
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
              #{topic_table_name}
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

        def asymmetric_posts_similarity_search(raw_vector, limit:, offset:, return_distance: false)
          results = DB.query(<<~SQL, query_embedding: raw_vector, limit: limit, offset: offset)
            SELECT
              post_id,
              embeddings #{pg_function} '[:query_embedding]' AS distance
            FROM
              #{post_table_name}
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
              #{topic_table_name}
            ORDER BY
              embeddings #{pg_function} (
                SELECT
                  embeddings
                FROM
                  #{topic_table_name}
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

        def topic_table_name
          "ai_topic_embeddings_#{id}_#{@strategy.id}"
        end

        def post_table_name
          "ai_post_embeddings_#{id}_#{@strategy.id}"
        end

        def table_name(target)
          case target
          when Topic
            topic_table_name
          when Post
            post_table_name
          else
            raise ArgumentError, "Invalid target type"
          end
        end

        def index_name(table_name)
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
          if target.is_a?(Topic)
            DB.exec(
              <<~SQL,
              INSERT INTO #{topic_table_name} (topic_id, model_version, strategy_version, digest, embeddings, created_at, updated_at)
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
          elsif target.is_a?(Post)
            DB.exec(
              <<~SQL,
              INSERT INTO #{post_table_name} (post_id, model_version, strategy_version, digest, embeddings, created_at, updated_at)
              VALUES (:post_id, :model_version, :strategy_version, :digest, '[:embeddings]', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
              ON CONFLICT (post_id)
              DO UPDATE SET
                model_version = :model_version,
                strategy_version = :strategy_version,
                digest = :digest,
                embeddings = '[:embeddings]',
                updated_at = CURRENT_TIMESTAMP
              SQL
              post_id: target.id,
              model_version: version,
              strategy_version: @strategy.version,
              digest: digest,
              embeddings: vector,
            )
          else
            raise ArgumentError, "Invalid target type"
          end
        end

        def discourse_embeddings_endpoint
          if SiteSetting.ai_embeddings_discourse_service_api_endpoint_srv.present?
            service =
              DiscourseAi::Utils::DnsSrv.lookup(
                SiteSetting.ai_embeddings_discourse_service_api_endpoint_srv,
              )
            "https://#{service.target}:#{service.port}"
          else
            SiteSetting.ai_embeddings_discourse_service_api_endpoint
          end
        end
      end
    end
  end
end
