# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiSpamController < ::Admin::AdminController
      requires_plugin "discourse-ai"

      def show
        render json: AiSpamSerializer.new(spam_config, root: false)
      end

      def update
        updated_params = {}

        updated_params[:llm_model_id] = allowed_params[:llm_model_id] if allowed_params.key?(
          :llm_model_id,
        )

        updated_params[:data] = {
          custom_instructions: allowed_params[:custom_instructions],
        } if allowed_params.key?(:custom_instructions)

        if updated_params.present?
          updated_params[:setting_type] = :spam
          AiModerationSetting.upsert(updated_params, unique_by: :setting_type)
        end

        is_enabled = ActiveModel::Type::Boolean.new.cast(allowed_params[:is_enabled])

        SiteSetting.ai_spam_detection_enabled = is_enabled if allowed_params.key?(:is_enabled)

        render json: AiSpamSerializer.new(spam_config, root: false)
      end

      private

      def allowed_params
        params.permit(:is_enabled, :llm_model_id, :custom_instructions)
      end

      def spam_config
        spam_config = { enabled: SiteSetting.ai_spam_detection_enabled, settings: AiModerationSetting.spam }

        spam_status = [Reviewable.statuses[:approved], Reviewable.statuses[:deleted]]
        ham_status = [Reviewable.statuses[:rejected], Reviewable.statuses[:ignored]]

        # todo maybe move this to a report class
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
            WHERE asl.created_at > :date
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

        stats = DB.query(sql, spam: spam_status, ham: ham_status, date: 1.week.ago).first

        spam_config[:stats] = stats
        spam_config

      end
    end
  end
end
