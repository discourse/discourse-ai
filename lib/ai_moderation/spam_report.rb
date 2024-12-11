# frozen_string_literal: true

module DiscourseAi
  module AiModeration
    class SpamReport
      def self.generate(min_date: 1.week.ago)
        spam_status = [Reviewable.statuses[:approved], Reviewable.statuses[:deleted]]
        ham_status = [Reviewable.statuses[:rejected], Reviewable.statuses[:ignored]]

        sql = <<~SQL
          WITH spam_stats AS (
            SELECT
              asl.reviewable_id,
              asl.post_id,
              asl.is_spam,
              r.status as reviewable_status,
              r.target_type,
              r.potential_spam
            FROM ai_spam_logs asl
            LEFT JOIN reviewables r ON r.id = asl.reviewable_id
            WHERE asl.created_at > :min_date
          ),
          post_reviewables AS (
            SELECT
              target_id post_id,
              COUNT(DISTINCT target_id) as false_negative_count
            FROM reviewables
            WHERE target_type = 'Post'
              AND status IN (:spam)
              AND potential_spam
              AND target_id IN (SELECT post_id FROM spam_stats)
            GROUP BY target_id
          )
          SELECT
            COUNT(*) AS scanned_count,
            SUM(CASE WHEN is_spam THEN 1 ELSE 0 END) AS spam_detected,
            COUNT(CASE WHEN reviewable_status IN (:ham) THEN 1 END) AS false_positives,
            COALESCE(SUM(pr.false_negative_count), 0) AS false_negatives
          FROM spam_stats
          LEFT JOIN post_reviewables pr USING (post_id)
        SQL

        DB.query(sql, spam: spam_status, ham: ham_status, min_date: min_date).first
      end
    end
  end
end
