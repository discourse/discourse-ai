# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class SummaryController < ::ApplicationController
      requires_plugin ::DiscourseAi::PLUGIN_NAME
      requires_login
      before_action :ensure_can_request_summaries

      def chat_channel
        chat_channel = Chat::Channel.find_by(id: params[:chat_channel_id])
        raise Discourse::InvalidParameters.new(:chat_channel_id) if !chat_channel

        RateLimiter.new(current_user, "ai_summarization", 6, 3.minutes).performed!

        hijack do
          render json: {
                   summary: DiscourseAi::Summarization::SummaryGenerator.summarize!(chat_channel),
                 },
                 status: 200
        end
      end

      private

      def ensure_can_request_summaries
        true
      end
    end
  end
end
