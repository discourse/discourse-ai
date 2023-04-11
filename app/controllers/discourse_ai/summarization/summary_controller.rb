# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class SummaryController < ::ApplicationController
      requires_plugin ::DiscourseAi::PLUGIN_NAME
      requires_login

      VALID_SINCE_VALUES = [1, 3, 6, 12, 24]
      VALID_TARGETS = %w[chat_channel topic]

      def show
        raise PluginDisabled unless SiteSetting.ai_summarization_enabled
        target_type = params[:target_type]

        raise Discourse::InvalidParameters.new(:target_type) if !VALID_TARGETS.include?(target_type)

        since = nil

        if target_type == "chat_channel"
          since = params[:since].to_i
          raise Discourse::InvalidParameters.new(:since) if !VALID_SINCE_VALUES.include?(since)
          target = Chat::Channel.find_by(id: params[:target_id])
          raise Discourse::NotFound.new(:chat_channel) if !target
          raise Discourse::InvalidAccess if !guardian.can_join_chat_channel?(target)
        else
          target = Topic.find_by(id: params[:target_id])
          raise Discourse::NotFound.new(:topic) if !target
          raise Discourse::InvalidAccess if !guardian.can_see_topic?(target)
        end

        RateLimiter.new(
          current_user,
          "ai_summarization",
          6,
          SiteSetting.ai_summarization_rate_limit_minutes.minutes,
        ).performed!

        hijack do
          summary =
            DiscourseAi::Summarization::SummaryGenerator.new(target, current_user).summarize!(since)

          render json: { summary: summary }, status: 200
        end
      end
    end
  end
end
