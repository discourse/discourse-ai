# frozen_string_literal: true

module DiscourseAi
  module Sentiment
    class EntryPoint
      def inject_into(plugin)
        sentiment_analysis_cb =
          Proc.new do |post|
            if SiteSetting.ai_sentiment_enabled
              Jobs.enqueue(:post_sentiment_analysis, post_id: post.id)
            end
          end

        plugin.on(:post_created, &sentiment_analysis_cb)
        plugin.on(:post_edited, &sentiment_analysis_cb)

        EmotionFilterOrder.register!(plugin)

        plugin.add_report("overall_sentiment") do |report|
          report.modes = [:stacked_chart]
          threshold = 0.6

          sentiment_count_sql = Proc.new { |sentiment| <<~SQL }
            COUNT(
              CASE WHEN (cr.classification::jsonb->'#{sentiment}')::float > :threshold THEN 1 ELSE NULL END
            ) AS #{sentiment}_count
          SQL

          grouped_sentiments =
            DB.query(
              <<~SQL,
            SELECT
              DATE_TRUNC('day', p.created_at)::DATE AS posted_at,
              #{sentiment_count_sql.call("positive")},
              -#{sentiment_count_sql.call("negative")}
            FROM
              classification_results AS cr
            INNER JOIN posts p ON p.id = cr.target_id AND cr.target_type = 'Post'
            INNER JOIN topics t ON t.id = p.topic_id
            INNER JOIN categories c ON c.id = t.category_id
            WHERE
              t.archetype = 'regular' AND
              p.user_id > 0 AND
              cr.model_used = 'cardiffnlp/twitter-roberta-base-sentiment-latest' AND
              (p.created_at > :report_start AND p.created_at < :report_end)
            GROUP BY DATE_TRUNC('day', p.created_at)
          SQL
              report_start: report.start_date,
              report_end: report.end_date,
              threshold: threshold,
            )

          data_points = %w[positive negative]

          return report if grouped_sentiments.empty?

          report.data =
            data_points.map do |point|
              {
                req: "sentiment_#{point}",
                color: point == "positive" ? report.colors[:lime] : report.colors[:purple],
                label: I18n.t("discourse_ai.sentiment.reports.overall_sentiment.#{point}"),
                data:
                  grouped_sentiments.map do |gs|
                    { x: gs.posted_at, y: gs.public_send("#{point}_count") }
                  end,
              }
            end
        end

        plugin.add_report("post_emotion") do |report|
          report.modes = [:stacked_line_chart]
          threshold = 0.3

          emotion_count_clause = Proc.new { |emotion| <<~SQL }
    COUNT(
      CASE WHEN (cr.classification::jsonb->'#{emotion}')::float > :threshold THEN 1 ELSE NULL END
    ) AS #{emotion}_count
  SQL

          grouped_emotions =
            DB.query(
              <<~SQL,
      SELECT
        DATE_TRUNC('day', p.created_at)::DATE AS posted_at,
        #{emotion_count_clause.call("sadness")},
        #{emotion_count_clause.call("surprise")},
        #{emotion_count_clause.call("fear")},
        #{emotion_count_clause.call("anger")},
        #{emotion_count_clause.call("joy")},
        #{emotion_count_clause.call("disgust")}
      FROM
        classification_results AS cr
      INNER JOIN posts p ON p.id = cr.target_id AND cr.target_type = 'Post'
      INNER JOIN users u ON p.user_id = u.id
      INNER JOIN topics t ON t.id = p.topic_id
      INNER JOIN categories c ON c.id = t.category_id
      WHERE
        t.archetype = 'regular' AND
        p.user_id > 0 AND
        cr.model_used = 'j-hartmann/emotion-english-distilroberta-base' AND
        (p.created_at > :report_start AND p.created_at < :report_end)
      GROUP BY DATE_TRUNC('day', p.created_at)
      SQL
              report_start: report.start_date,
              report_end: report.end_date,
              threshold: threshold,
            )

          return report if grouped_emotions.empty?

          emotions = [
            { name: "sadness", color: report.colors[:turquoise] },
            { name: "disgust", color: report.colors[:lime] },
            { name: "fear", color: report.colors[:purple] },
            { name: "anger", color: report.colors[:magenta] },
            { name: "joy", color: report.colors[:yellow] },
            { name: "surprise", color: report.colors[:brown] },
          ]

          report.data =
            emotions.map do |emotion|
              {
                req: "emotion_#{emotion[:name]}",
                color: emotion[:color],
                label: I18n.t("discourse_ai.sentiment.reports.post_emotion.#{emotion[:name]}"),
                data:
                  grouped_emotions.map do |ge|
                    { x: ge.posted_at, y: ge.public_send("#{emotion[:name]}_count") }
                  end,
              }
            end
        end
      end
    end
  end
end
