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

          grouped_sentiments =
            DB.query(<<~SQL, report_start: report.start_date, report_end: report.end_date)
            SELECT 
              DATE_TRUNC('day', p.created_at)::DATE AS posted_at,
              AVG((cr.classification::jsonb->'positive')::integer) AS avg_positive,
              -AVG((cr.classification::jsonb->'negative')::integer) AS avg_negative
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

          data_points = %w[positive negative]

          report.data =
            data_points.map do |point|
              {
                req: "sentiment_#{point}",
                color: point == "positive" ? report.colors[1] : report.colors[3],
                label: I18n.t("discourse_ai.sentiment.reports.overall_sentiment.#{point}"),
                data:
                  grouped_sentiments.map do |gs|
                    { x: gs.posted_at, y: gs.public_send("avg_#{point}") }
                  end,
              }
            end
        end

        plugin.add_report("post_emotion") do |report|
          report.modes = [:radar]

          grouped_emotions =
            DB.query(<<~SQL, report_start: report.start_date, report_end: report.end_date)
            SELECT 
              u.trust_level AS trust_level,
              AVG((cr.classification::jsonb->'sadness')::integer) AS avg_sadness,
              AVG((cr.classification::jsonb->'surprise')::integer) AS avg_surprise,
              AVG((cr.classification::jsonb->'neutral')::integer) AS avg_neutral,
              AVG((cr.classification::jsonb->'fear')::integer) AS avg_fear,
              AVG((cr.classification::jsonb->'anger')::integer) AS avg_anger,
              AVG((cr.classification::jsonb->'joy')::integer) AS avg_joy,
              AVG((cr.classification::jsonb->'disgust')::integer) AS avg_disgust
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

          emotions = %w[sadness surprise neutral fear anger joy disgust]
          level_groups = [[0, 1], [2, 3, 4]]

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
                          tl_emotion_avg.public_send("avg_#{e}").to_i
                        end / [tl_emotion_avgs.size, 1].max,
                    }
                  end,
              }
            end
        end
      end
    end
  end
end
