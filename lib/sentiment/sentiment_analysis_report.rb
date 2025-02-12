# frozen_string_literal: true

module DiscourseAi
  module Sentiment
    class SentimentAnalysisReport
      def self.register!(plugin)
        plugin.add_report("sentiment_analysis") do |report|
          report.modes = [:sentiment_analysis]
          category_filter = report.filters.dig(:group_by) || :category
          report.add_filter(
            "group_by",
            type: "list",
            default: category_filter,
            choices: [{ id: "category", name: "Category" }, { id: "tag", name: "Tag" }],
            allow_any: false,
            auto_insert_none_item: false,
          )
          size_filter = report.filters.dig(:sort_by) || :size
          report.add_filter(
            "sort_by",
            type: "list",
            default: size_filter,
            choices: [{ id: "size", name: "Size" }, { id: "alphabetical", name: "Alphabetical" }],
            allow_any: false,
            auto_insert_none_item: false,
          )

          sentiment_data = DiscourseAi::Sentiment::SentimentAnalysisReport.fetch_data(report)

          report.data = sentiment_data

          # TODO: connect filter to make the report data change.

          report.labels = [
            I18n.t("discourse_ai.sentiment.reports.sentiment_analysis.positive"),
            I18n.t("discourse_ai.sentiment.reports.sentiment_analysis.neutral"),
            I18n.t("discourse_ai.sentiment.reports.sentiment_analysis.negative"),
          ]
        end
      end

      def self.fetch_data(report)
        grouping = report.filters.dig(:group_by).to_sym
        sorting = report.filters.dig(:sort_by).to_sym
        threshold = DiscourseAi::Sentiment::SentimentController::SENTIMENT_THRESHOLD

        sentiment_count_sql = Proc.new { |sentiment| <<~SQL }
          COUNT(
            CASE WHEN (cr.classification::jsonb->'#{sentiment}')::float > :threshold THEN 1 ELSE NULL END
          )
        SQL

        grouping_clause =
          case grouping
          when :category
            <<~SQL
                c.name AS category_name,
              SQL
          when :tag
            <<~SQL
                  tags.name AS tag_name,
              SQL
          else
            raise Discourse::InvalidParameters
          end

        grouping_join =
          case grouping
          when :category
            <<~SQL
              INNER JOIN categories c ON c.id = t.category_id
            SQL
          when :tag
            <<~SQL
              INNER JOIN topic_tags tt ON tt.topic_id = p.topic_id
              INNER JOIN tags ON tags.id = tt.tag_id
            SQL
          else
            raise Discourse::InvalidParameters
          end

        order_by_clause =
          case sorting
          when :size
            "ORDER BY total_count DESC"
          when :alphabetical
            "ORDER BY 1 ASC"
          else
            raise Discourse::InvalidParameters
          end

        grouped_sentiments =
          DB.query(
            <<~SQL,
              SELECT
                #{grouping_clause}
                #{sentiment_count_sql.call("positive")} AS positive_count,
                #{sentiment_count_sql.call("negative")} AS negative_count,
                COUNT(*) AS total_count
              FROM
                classification_results AS cr
              INNER JOIN posts p ON p.id = cr.target_id AND cr.target_type = 'Post'
              INNER JOIN topics t ON t.id = p.topic_id
              #{grouping_join}
              WHERE
                t.archetype = 'regular' AND
                p.user_id > 0 AND
                cr.model_used = 'cardiffnlp/twitter-roberta-base-sentiment-latest' AND
                (p.created_at > :report_start AND p.created_at < :report_end)
              GROUP BY 1
              #{order_by_clause}
            SQL
            report_start: report.start_date,
            report_end: report.end_date,
            threshold: threshold,
          )

        grouped_sentiments
      end
    end
  end
end
