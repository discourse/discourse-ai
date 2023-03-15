# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    class SemanticSuggested
      def self.build_suggested_topics(topic, pm_params, topic_query)
        return unless SiteSetting.ai_embeddings_semantic_suggested_topics_anons_enabled
        return if topic_query.user
        return if topic.private_message?

        model = SiteSetting.ai_embeddings_semantic_suggested_topics_model

        begin
          candidate_ids =
            Discourse
              .cache
              .fetch("semantic-suggested-topic-#{topic.id}", expires_in: 1.hour) do
                DiscourseAi::Database::Connection.db.query(<<~SQL, topic_id: topic.id).map(&:topic_id)
                  SELECT
                    topic_id
                  FROM
                    topic_embeddings_#{model.underscore}
                  WHERE
                    topic_id != :topic_id
                  ORDER BY
                    embeddings <#> (
                      SELECT
                        embeddings
                      FROM
                        topic_embeddings_#{model.underscore}
                      WHERE
                        topic_id = :topic_id
                      LIMIT 1
                    )
                  LIMIT 10
                SQL
              end
        rescue StandardError => e
          Rails.logger.error("SemanticSuggested: #{e}")
        end

        candidates = ::Topic.where(id: candidate_ids)
        { result: candidates, params: {} }
      end
    end
  end
end
