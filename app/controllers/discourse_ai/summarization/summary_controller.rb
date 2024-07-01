# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class SummaryController < ::ApplicationController
      requires_plugin ::DiscourseAi::PLUGIN_NAME

      def show
        topic = Topic.find(params[:topic_id])
        guardian.ensure_can_see!(topic)
        strategy = DiscourseAi::Summarization::Models::Base.selected_strategy

        if strategy.nil? ||
             !DiscourseAi::Summarization::Models::Base.can_see_summary?(topic, current_user)
          raise Discourse::NotFound
        end

        RateLimiter.new(current_user, "summary", 6, 5.minutes).performed! if current_user

        opts = params.permit(:skip_age_check)

        if params[:stream] && current_user
          Jobs.enqueue(
            :stream_topic_ai_summary,
            topic_id: topic.id,
            user_id: current_user.id,
            opts: opts.as_json,
          )

          render json: success_json
        else
          hijack do
            summary =
              DiscourseAi::TopicSummarization.new(strategy).summarize(topic, current_user, opts)

            render_serialized(summary, AiTopicSummarySerializer)
          end
        end
      end
    end
  end
end
