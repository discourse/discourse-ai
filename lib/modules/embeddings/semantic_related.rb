# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    class SemanticRelated
      def self.semantic_suggested_key(topic_id)
        "semantic-suggested-topic-#{topic_id}"
      end

      def self.build_semantic_suggested_key(topic_id)
        "build-semantic-suggested-topic-#{topic_id}"
      end

      def self.clear_cache_for(topic)
        Discourse.cache.delete(semantic_suggested_key(topic.id))
        Discourse.redis.del(build_semantic_suggested_key(topic.id))
      end

      def self.candidates_for(topic)
        return ::Topic.none if SiteSetting.ai_embeddings_semantic_related_topics < 1

        cache_for =
          case topic.created_at
          when 6.hour.ago..Time.now
            15.minutes
          when 1.day.ago..6.hour.ago
            1.hour
          else
            1.day
          end

        model =
          DiscourseAi::Embeddings::Model.instantiate(
            SiteSetting.ai_embeddings_semantic_related_model,
          )

        begin
          candidate_ids =
            Discourse
              .cache
              .fetch(semantic_suggested_key(topic.id), expires_in: cache_for) do
                DiscourseAi::Embeddings::Topic.new.symmetric_semantic_search(model, topic)
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
          return ::Topic.none
        end

        topic_list = ::Topic.visible.listable_topics.secured

        unless SiteSetting.ai_embeddings_semantic_related_include_closed_topics
          topic_list = topic_list.where(closed: false)
        end

        topic_list
          .where("id <> ?", topic.id)
          .where(id: candidate_ids)
          # array_position forces the order of the topics to be preserved
          .order("array_position(ARRAY#{candidate_ids}, id)")
          .limit(SiteSetting.ai_embeddings_semantic_related_topics)
      end
    end
  end
end
