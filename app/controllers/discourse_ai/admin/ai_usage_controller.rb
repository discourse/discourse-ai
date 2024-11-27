# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiUsageController < ::Admin::AdminController
      requires_plugin "discourse-ai"

      def show
        render json: AiUsageSerializer.new(create_report, root: false)
      end

      private

      def create_report
        report =
          DiscourseAi::Completions::Report.new(
            start_date: params[:start_date]&.to_date || 30.days.ago,
            end_date: params[:end_date]&.to_date || Time.current,
          )

        report = report.filter_by_feature(params[:feature]) if params[:feature].present?
        report = report.filter_by_model(params[:model]) if params[:model].present?
        report
      end

      def time_series_data(report)
        case params[:period]
        when "hour"
          report.tokens_per_hour
        when "month"
          report.tokens_per_month
        else
          report.tokens_per_day
        end
      end
    end
  end
end
