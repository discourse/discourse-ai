# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class SummaryController < ::ApplicationController
      requires_plugin ::DiscourseAi::PLUGIN_NAME

      def show
        topic = Topic.find(params[:topic_id])
        guardian.ensure_can_see!(topic)

        raise Discourse::NotFound if !guardian.can_see_summary?(topic)

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
            summary = DiscourseAi::TopicSummarization.summarize(topic, current_user, opts)
            render_serialized(summary, AiTopicSummarySerializer)
          end
        end
      end
    end
  end
end
