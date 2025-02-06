# frozen_string_literal: true

# TODO: Currently returns all posts, need to add pagination?

module DiscourseAi
  module Sentiment
    class SentimentAnalysisReport
      def self.register!(plugin)
        plugin.add_report("sentiment_analysis") do |report|
          report.modes = [:sentiment_analysis]
          sentiment_data = DiscourseAi::Sentiment::SentimentAnalysisReport.fetch_data(report)

          # Group posts by category
          # ! TODO: by tags?
          grouped_data = sentiment_data.group_by { |row| row[:category_name] }
          report.data =
            grouped_data.map do |category_name, posts|
              total_positive = posts.sum { |p| p[:positive_score] }
              total_negative = posts.sum { |p| p[:negative_score] }
              total_neutral = posts.sum { |p| p[:neutral_score] }
              count = posts.size.to_f

              {
                category_name: category_name,
                overall_scores: {
                  positive: (total_positive / count).round(2),
                  negative: (total_negative / count).round(2),
                  neutral: (total_neutral / count).round(2),
                },
                posts:
                  posts.map do |p|
                    {
                      topic_id: p[:topic_id],
                      title: p[:title],
                      post_id: p[:post_id],
                      post_number: p[:post_number],
                      username: p[:username],
                      excerpt: p[:post_excerpt],
                      category_id: p[:category_id],
                      tag_names: p[:tag_names],
                      positive_score: p[:positive_score].round(2),
                      negative_score: p[:negative_score].round(2),
                      neutral_score: p[:neutral_score].round(2),
                      postUrl: "/t/#{p[:topic_id]}/#{p[:post_number]}",
                    }
                  end,
              }
            end

          # TODO: connect filter to make the report data change.
          filter_type = report.filters.dig(:filter_type) || "Category"
          report.add_filter(
            "filter_by",
            type: "list",
            default: filter_type,
            choices: [{ id: "category", name: "Category" }, { id: "tag", name: "Tag" }],
            allow_any: false,
            auto_insert_none_item: false,
          )

          report.labels = [
            I18n.t("discourse_ai.sentiment.reports.sentiment_analysis.positive"),
            I18n.t("discourse_ai.sentiment.reports.sentiment_analysis.neutral"),
            I18n.t("discourse_ai.sentiment.reports.sentiment_analysis.negative"),
          ]
        end
      end

      def self.fetch_data(report)
        DB
          .query(<<~SQL, report_start: report.start_date, report_end: report.end_date)
          WITH topic_tags_cte AS (
              SELECT 
                  tt.topic_id,
                  string_agg(DISTINCT tags.name, ',') AS tag_names
              FROM topic_tags tt
              JOIN tags ON tags.id = tt.tag_id
              GROUP BY tt.topic_id
          )
          SELECT
              t.id AS topic_id,
              t.title,
              p.id AS post_id,
              p.post_number,
              u.username,
              LEFT(p.cooked, 300) AS post_excerpt,
              c.id AS category_id,
              c.name AS category_name,
              COALESCE(tt.tag_names, '') AS tag_names,
              (cr.classification::jsonb->'positive')::float AS positive_score,
              (cr.classification::jsonb->'negative')::float AS negative_score
          FROM classification_results cr
          JOIN posts p 
              ON p.id = cr.target_id 
              AND cr.target_type = 'Post'
          JOIN topics t 
              ON t.id = p.topic_id
          JOIN categories c 
              ON c.id = t.category_id
          JOIN users u
              ON u.id = p.user_id
          LEFT JOIN topic_tags_cte tt
              ON tt.topic_id = t.id
          WHERE 
              p.created_at BETWEEN :report_start AND :report_end
              AND cr.model_used = 'cardiffnlp/twitter-roberta-base-sentiment-latest'
              AND p.deleted_at IS NULL
              AND p.hidden = FALSE
              AND t.deleted_at IS NULL
              AND t.visible = TRUE
              AND t.archetype != 'private_message'
              AND c.read_restricted = FALSE
          ORDER BY 
              c.name, 
              (cr.classification::jsonb->'negative')::float DESC
        SQL
          .map do |row|
            # Add neutral score and structure data
            positive_score = row.positive_score || 0.0
            negative_score = row.negative_score || 0.0
            neutral_score = 1.0 - (positive_score + negative_score)

            {
              category_name: row.category_name,
              topic_id: row.topic_id,
              title: row.title,
              post_id: row.post_id,
              post_number: row.post_number,
              username: row.username,
              post_excerpt: row.post_excerpt,
              category_id: row.category_id,
              tag_names: row.tag_names,
              positive_score: positive_score,
              negative_score: negative_score,
              neutral_score: neutral_score,
            }
          end
      end
    end
  end
end
