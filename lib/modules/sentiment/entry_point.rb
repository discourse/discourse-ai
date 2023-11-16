# frozen_string_literal: true

module DiscourseAi
  module Sentiment
    class EntryPoint
      def load_files
        require_relative "sentiment_classification"
        require_relative "jobs/regular/post_sentiment_analysis"
      end

      def inject_into(plugin)
        sentiment_analysis_cb =
          Proc.new do |post|
            if SiteSetting.ai_sentiment_enabled
              Jobs.enqueue(:post_sentiment_analysis, post_id: post.id)
            end
          end

        plugin.on(:post_created, &sentiment_analysis_cb)
        plugin.on(:post_edited, &sentiment_analysis_cb)

        plugin.add_report("overall_sentiment") do |report|
          report.modes = [:stacked_chart]
          threshold = 60

          sentiment_count_sql = Proc.new { |sentiment| <<~SQL }
            COUNT(
              CASE WHEN (cr.classification::jsonb->'#{sentiment}')::integer > :threshold THEN 1 ELSE NULL END
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
              cr.model_used = 'sentiment' AND
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
                color: point == "positive" ? report.colors[1] : report.colors[3],
                label: I18n.t("discourse_ai.sentiment.reports.overall_sentiment.#{point}"),
                data:
                  grouped_sentiments.map do |gs|
                    { x: gs.posted_at, y: gs.public_send("#{point}_count") }
                  end,
              }
            end
        end

        plugin.add_report("post_emotion") do |report|
          report.modes = [:radar]
          threshold = 30

          emotion_count_clause = Proc.new { |emotion| <<~SQL }
            COUNT(
              CASE WHEN (cr.classification::jsonb->'#{emotion}')::integer > :threshold THEN 1 ELSE NULL END
            ) AS #{emotion}_count
          SQL

          grouped_emotions =
            DB.query(
              <<~SQL,
            SELECT 
              u.trust_level AS trust_level,
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
              cr.model_used = 'emotion' AND
              (p.created_at > :report_start AND p.created_at < :report_end)
            GROUP BY u.trust_level
          SQL
              report_start: report.start_date,
              report_end: report.end_date,
              threshold: threshold,
            )

          emotions = %w[sadness disgust fear anger joy surprise]
          level_groups = [[0, 1], [2, 3, 4]]

          return report if grouped_emotions.empty?

          report.data =
            level_groups.each_with_index.map do |lg, idx|
              tl_emotion_avgs = grouped_emotions.select { |ge| lg.include?(ge.trust_level) }

              {
                req: "emotion_tl_#{lg.join}",
                color: report.colors[idx],
                label: I18n.t("discourse_ai.sentiment.reports.post_emotion.tl_#{lg.join}"),
                data:
                  emotions.map do |e|
                    {
                      x: I18n.t("discourse_ai.sentiment.reports.post_emotion.#{e}"),
                      y:
                        tl_emotion_avgs.sum do |tl_emotion_avg|
                          tl_emotion_avg.public_send("#{e}_count").to_i
                        end,
                    }
                  end,
              }
            end
        end
      end
    end
  end
end
