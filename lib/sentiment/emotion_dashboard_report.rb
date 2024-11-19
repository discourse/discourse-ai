# frozen_string_literal: true

module DiscourseAi
  module Sentiment
    class EmotionDashboardReport
      def self.register!(plugin)
        Emotions::LIST.each do |emotion|
          plugin.add_report("emotion_#{emotion}") do |report|
            query_results = DiscourseAi::Sentiment::EmotionDashboardReport.fetch_data
            report.data = query_results.pop(30).map { |row| { x: row.day, y: row.send(emotion) } }
            report.prev30Days =
              query_results.take(30).map { |row| { x: row.day, y: row.send(emotion) } }
          end
        end

        def self.fetch_data
          DB.query(<<~SQL, end: Time.now.tomorrow.midnight, start: 60.days.ago.midnight)
            SELECT
              posts.created_at::DATE AS day,
              #{
              DiscourseAi::Sentiment::Emotions::LIST
                .map do |emotion|
                  "COUNT(*) FILTER (WHERE (classification_results.classification::jsonb->'#{emotion}')::float > 0.1) AS #{emotion}"
                end
                .join(",\n  ")
            }
            FROM
                classification_results
            INNER JOIN
                posts ON posts.id = classification_results.target_id AND
                posts.deleted_at IS NULL AND
                posts.created_at BETWEEN :start AND :end
            INNER JOIN
                topics ON topics.id = posts.topic_id AND
                topics.archetype = 'regular' AND
                topics.deleted_at IS NULL
            WHERE
                classification_results.target_type = 'Post' AND
                classification_results.model_used = 'SamLowe/roberta-base-go_emotions'
            GROUP BY 1
            ORDER BY 1 ASC
          SQL
        end
      end
    end
  end
end
