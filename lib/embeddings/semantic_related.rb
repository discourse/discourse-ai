# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    class SemanticRelated
      MissingEmbeddingError = Class.new(StandardError)

      def self.clear_cache_for(topic)
        Discourse.cache.delete("semantic-suggested-topic-#{topic.id}")
        Discourse.redis.del("build-semantic-suggested-topic-#{topic.id}")
      end

      def related_topic_ids_for(topic)
        return [] if SiteSetting.ai_embeddings_semantic_related_topics < 1

        strategy = DiscourseAi::Embeddings::Strategies::Truncation.new
        vector_rep =
          DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(strategy)
        cache_for = results_ttl(topic)

        Discourse
          .cache
          .fetch(semantic_suggested_key(topic.id), expires_in: cache_for) do
            vector_rep
              .symmetric_topics_similarity_search(topic)
              .tap do |candidate_ids|
                # Happens when the topic doesn't have any embeddings
                # I'd rather not use Exceptions to control the flow, so this should be refactored soon
                if candidate_ids.empty? || !candidate_ids.include?(topic.id)
                  raise MissingEmbeddingError, "No embeddings found for topic #{topic.id}"
                end
              end
          end
      rescue MissingEmbeddingError
        # avoid a flood of jobs when visiting topic
        if Discourse.redis.set(
             build_semantic_suggested_key(topic.id),
             "queued",
             ex: 15.minutes.to_i,
             nx: true,
           )
          Jobs.enqueue(:generate_embeddings, target_type: "Topic", target_id: topic.id)
        end
        []
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

      def self.related_topics_for_crawler(controller)
        return "" if !controller.instance_of? TopicsController
        return "" if !SiteSetting.ai_embeddings_semantic_related_topics_enabled
        return "" if SiteSetting.ai_embeddings_semantic_related_topics < 1

        topic_view = controller.instance_variable_get(:@topic_view)
        topic = topic_view&.topic
        return "" if !topic

        related_topics = SemanticTopicQuery.new(nil).list_semantic_related_topics(topic).topics

        return "" if related_topics.empty?

        ApplicationController.render(
          template: "list/related_topics",
          layout: false,
          assigns: {
            list: related_topics,
            topic: topic,
          },
        )
      end

      private

      def semantic_suggested_key(topic_id)
        "semantic-suggested-topic-#{topic_id}"
      end

      def build_semantic_suggested_key(topic_id)
        "build-semantic-suggested-topic-#{topic_id}"
      end
    end
  end
end
