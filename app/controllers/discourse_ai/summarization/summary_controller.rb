# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class SummaryController < ::ApplicationController
      requires_plugin ::DiscourseAi::PLUGIN_NAME
      requires_login

      VALID_SINCE_VALUES = [1, 3, 6, 12, 24]

      def chat_channel
        since = params[:since].to_i

        raise Discourse::InvalidParameters.new(:since) if !VALID_SINCE_VALUES.include?(since)
        chat_channel = Chat::Channel.find_by(id: params[:chat_channel_id])
        raise Discourse::NotFound.new(:chat_channel) if !chat_channel

        RateLimiter.new(
          current_user,
          "ai_summarization",
          6,
          SiteSetting.ai_summarization_rate_limit_minutes.minutes,
        ).performed!

        hijack do
          summary = DiscourseAi::Summarization::SummaryGenerator.new(chat_channel).summarize!(since)

          render json: { summary: summary }, status: 200
        end
      end
    end
  end
end
