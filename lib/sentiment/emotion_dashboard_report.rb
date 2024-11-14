# frozen_string_literal: true

module DiscourseAi
  module Sentiment
    class EmotionDashboardReport
      def self.report
        periods = {
          today: {
            start: 1.day.ago,
            end: Time.zone.now,
          },
          yesterday: {
            start: 2.days.ago,
            end: 1.day.ago,
          },
          yesterday_comparison: {
            start: 3.days.ago,
            end: 2.days.ago,
          },
          week: {
            start: 1.week.ago,
            end: Time.zone.now,
          },
          week_comparison: {
            start: 2.weeks.ago,
            end: 1.week.ago,
          },
          month: {
            start: 1.month.ago,
            end: Time.zone.now,
          },
          month_comparison: {
            start: 2.months.ago,
            end: 1.month.ago,
          },
        }

        report = {}
        periods.each do |period, range|
          report[period] = DB.query(<<~SQL, start: range[:start], end: range[:end]).first.to_h
            SELECT
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
              posts.created_at >= :start AND
              posts.created_at < :end
            INNER JOIN
              topics ON topics.id = posts.topic_id AND
              topics.archetype = 'regular' AND
              topics.deleted_at IS NULL
            WHERE
              classification_results.target_type = 'Post' AND
              classification_results.model_used = 'SamLowe/roberta-base-go_emotions'
          SQL
        end
      end
    end
  end
end
