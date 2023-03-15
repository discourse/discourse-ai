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
        end

        candidates = ::Topic.where(id: candidate_ids)
        { result: candidates, params: {} }
      end

      def self.search_suggestions(topic)
        model_name = SiteSetting.ai_embeddings_semantic_suggested_model
        model = DiscourseAi::Embeddings::Models.list.find { |m| m.name == model_name }
        function =
          DiscourseAi::Embeddings::Models::SEARCH_FUNCTION_TO_PG_FUNCTION[model.functions.first]

        DiscourseAi::Database::Connection.db.query(<<~SQL, topic_id: topic.id).map(&:topic_id)
          SELECT
            topic_id
          FROM
            topic_embeddings_#{model_name.underscore}
          WHERE
            topic_id != :topic_id
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
          LIMIT 10
        SQL
      end
    end
  end
end
