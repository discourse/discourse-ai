module DiscourseAi
  module Completions
    class Report
      attr_reader :start_date, :end_date, :base_query

      def initialize(start_date: 30.days.ago, end_date: Time.current)
        @start_date = start_date.beginning_of_day
        @end_date = end_date.end_of_day
        @base_query = AiApiAuditLog.where(created_at: @start_date..@end_date)
      end

      def total_tokens
        base_query.sum("request_tokens + response_tokens")
      end

      def guess_period(period)
        period = nil if %i[day month hour].include?(period)
        period ||
          case @end_date - @start_date
          when 0..7.days
            :hour
          when 7.days..90.days
            :day
          else
            :month
          end
      end

      def tokens_by_period(period = nil)
        period = guess_period(period)
        base_query
          .group("DATE_TRUNC('#{period}', created_at)")
          .order("DATE_TRUNC('#{period}', created_at)")
          .select(
            "DATE_TRUNC('#{period}', created_at) as period",
            "SUM(request_tokens + response_tokens) as total_tokens",
            "SUM(COALESCE(cached_tokens,0)) as total_cached_tokens",
            "SUM(request_tokens) as total_request_tokens",
            "SUM(response_tokens) as total_response_tokens",
          )
      end

      def feature_breakdown
        base_query
          .group(:feature_name)
          .order("usage_count DESC")
          .select(
            "feature_name",
            "COUNT(*) as usage_count",
            "SUM(request_tokens + response_tokens) as total_tokens",
            "SUM(COALESCE(cached_tokens,0)) as total_cached_tokens",
            "SUM(request_tokens) as total_request_tokens",
            "SUM(response_tokens) as total_response_tokens",
          )
      end

      def model_breakdown
        base_query
          .group(:language_model)
          .order("usage_count DESC")
          .select(
            "language_model as llm",
            "COUNT(*) as usage_count",
            "SUM(request_tokens + response_tokens) as total_tokens",
            "SUM(COALESCE(cached_tokens,0)) as total_cached_tokens",
            "SUM(request_tokens) as total_request_tokens",
            "SUM(response_tokens) as total_response_tokens",
          )
      end

      def tokens_per_hour
        tokens_by_period(:hour)
      end

      def tokens_per_day
        tokens_by_period(:day)
      end

      def tokens_per_month
        tokens_by_period(:month)
      end

      def filter_by_feature(feature_name)
        @base_query = base_query.where(feature_name: feature_name)
        self
      end

      def filter_by_model(model_name)
        @base_query = base_query.where(language_model: model_name)
        self
      end
    end
  end
end
