# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    class SemanticRelated
      MissingEmbeddingError = Class.new(StandardError)

      class << self
        def semantic_suggested_key(topic_id)
          "semantic-suggested-topic-#{topic_id}"
        end

        def build_semantic_suggested_key(topic_id)
          "build-semantic-suggested-topic-#{topic_id}"
        end

        def clear_cache_for(topic)
          Discourse.cache.delete(semantic_suggested_key(topic.id))
          Discourse.redis.del(build_semantic_suggested_key(topic.id))
        end

        def related_topic_ids_for(topic)
          return [] if SiteSetting.ai_embeddings_semantic_related_topics < 1

          manager = DiscourseAi::Embeddings::Manager.new(topic)
          cache_for = results_ttl(topic)

          begin
            Discourse
              .cache
              .fetch(semantic_suggested_key(topic.id), expires_in: cache_for) do
                symmetric_semantic_search(manager)
              end
          rescue MissingEmbeddingError
            # avoid a flood of jobs when visiting topic
            if Discourse.redis.set(
                 build_semantic_suggested_key(topic.id),
                 "queued",
                 ex: 15.minutes.to_i,
                 nx: true,
               )
              Jobs.enqueue(:generate_embeddings, topic_id: topic.id)
            end
            []
          end
        end

        def symmetric_semantic_search(manager)
          topic = manager.target
          candidate_ids = self.query_symmetric_embeddings(manager)

          # Happens when the topic doesn't have any embeddings
          # I'd rather not use Exceptions to control the flow, so this should be refactored soon
          if candidate_ids.empty? || !candidate_ids.include?(topic.id)
            raise MissingEmbeddingError, "No embeddings found for topic #{topic.id}"
          end

          candidate_ids
        end

        def query_symmetric_embeddings(manager)
          topic = manager.target
          model = manager.model
          table = manager.topic_embeddings_table
          begin
            DB.query(<<~SQL, topic_id: topic.id).map(&:topic_id)
            SELECT
              topic_id
            FROM
              #{table}
            ORDER BY
              embeddings #{model.pg_function} (
                SELECT
                  embeddings
                FROM
                  #{table}
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
            raise MissingEmbeddingError
          end
        end

        def results_ttl(topic)
          case topic.created_at
          when 6.hour.ago..Time.now
            15.minutes
          when 3.day.ago..6.hour.ago
            1.hour
          when 15.days.ago..3.day.ago
            12.hours
          else
            1.week
          end
        end
      end
    end
  end
end
