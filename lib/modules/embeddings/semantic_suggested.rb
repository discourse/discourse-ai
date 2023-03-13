# frozen_string_literal: true

module DiscourseAI
  module Embeddings
    class SemanticSuggested
      def self.build_suggested_topics(topic, pm_params, topic_query)
        return unless SiteSetting.ai_embeddings_semantic_suggested_topics_anons_enabled
        return if topic_query.user
        return if topic.private_message?

        candidate_ids = DiscourseAI::Database::Connection.db.query(<<~SQL, topic_id: topic.id)
          SELECT
            topic_id
          FROM
            topic_embeddings_symetric_discourse
          WHERE
            topic_id != :topic_id
          ORDER BY
            embeddings <#> (
              SELECT
                embeddings
              FROM
                topic_embeddings_symetric_discourse
              WHERE
                topic_id = :topic_id
              LIMIT 1
            )
          LIMIT 10
        SQL

        candidates = ::Topic.where(id: candidate_ids.map(&:topic_id))
        { result: candidates, params: {} }
      end
    end
  end
end
