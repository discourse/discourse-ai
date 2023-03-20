# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    class SemanticSuggested
      def self.build_suggested_topics(topic, pm_params, topic_query)
        return unless SiteSetting.ai_embeddings_semantic_suggested_topics_anons_enabled
        return if topic_query.user
        return if topic.private_message?

        cache_for =
          case topic.created_at
          when 6.hour.ago..Time.now
            15.minutes
          when 1.day.ago..6.hour.ago
            1.hour
          else
            1.day
          end

        begin
          candidate_ids =
            Discourse
              .cache
              .fetch("semantic-suggested-topic-#{topic.id}", expires_in: cache_for) do
                search_suggestions(topic)
              end
        rescue StandardError => e
          Rails.logger.error("SemanticSuggested: #{e}")
          return { result: [], params: {} }
        end

        # array_position forces the order of the topics to be preserved
        candidates =
          ::Topic.where(id: candidate_ids).order("array_position(ARRAY#{candidate_ids}, id)")

        { result: candidates, params: {} }
      end

      def self.search_suggestions(topic)
        model_name = SiteSetting.ai_embeddings_semantic_suggested_model
        model = DiscourseAi::Embeddings::Models.list.find { |m| m.name == model_name }
        function =
          DiscourseAi::Embeddings::Models::SEARCH_FUNCTION_TO_PG_FUNCTION[model.functions.first]

        candidate_ids =
          DiscourseAi::Database::Connection.db.query(<<~SQL, topic_id: topic.id).map(&:topic_id)
          SELECT
            topic_id
          FROM
            topic_embeddings_#{model_name.underscore}
          ORDER BY
            embedding #{function} (
              SELECT
                embedding
              FROM
                topic_embeddings_#{model_name.underscore}
              WHERE
                topic_id = :topic_id
              LIMIT 1
            )
          LIMIT 11
        SQL

        # Happens when the topic doesn't have any embeddings
        # I'd rather not use Exceptions to control the flow, so this should be refactored soon
        if candidate_ids.empty? || !candidate_ids.include?(topic.id)
          raise StandardError, "No embeddings found for topic #{topic.id}"
        end

        candidate_ids
      end
    end
  end
end
