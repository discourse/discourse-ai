# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class ChatSummaryController < ::ApplicationController
      requires_plugin ::DiscourseAi::PLUGIN_NAME
      requires_plugin ::Chat::PLUGIN_NAME

      VALID_SINCE_VALUES = [1, 3, 6, 12, 24, 72, 168]

      def show
        since = params[:since].to_i
        raise Discourse::InvalidParameters.new(:since) if !VALID_SINCE_VALUES.include?(since)

        channel = ::Chat::Channel.find(params[:channel_id])
        guardian.ensure_can_join_chat_channel!(channel)

        strategy = DiscourseAi::Summarization::Models::Base.selected_strategy
        raise Discourse::NotFound.new unless strategy
        unless DiscourseAi::Summarization::Models::Base.can_request_summary_for?(current_user)
          raise Discourse::InvalidAccess
        end

        RateLimiter.new(current_user, "channel_summary", 6, 5.minutes).performed!

        hijack do
          content = { content_title: channel.name }

          content[:contents] = channel
            .chat_messages
            .where("chat_messages.created_at > ?", since.hours.ago)
            .includes(:user)
            .order(created_at: :asc)
            .pluck(:id, :username_lower, :message)
            .map { { id: _1, poster: _2, text: _3 } }

          summarized_text =
            if content[:contents].empty?
              I18n.t("discourse_ai.summarization.chat.no_targets")
            else
              strategy.summarize(content, current_user).dig(:summary)
            end

          render json: { summary: summarized_text }
        end
      end
    end
  end
end
