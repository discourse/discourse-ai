# frozen_string_literal: true

module Jobs
  class StreamTopicAiSummary < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return unless topic = Topic.find_by(id: args[:topic_id])
      return unless user = User.find_by(id: args[:user_id])

      strategy = DiscourseAi::Summarization.default_strategy
      return if strategy.nil? || !Guardian.new(user).can_see_summary?(topic)

      guardian = Guardian.new(user)
      return unless guardian.can_see?(topic)

      opts = args[:opts] || {}

      streamed_summary = +""
      start = Time.now

      summary =
        DiscourseAi::TopicSummarization
          .new(strategy)
          .summarize(topic, user, opts) do |partial_summary|
            streamed_summary << partial_summary

            # Throttle updates.
            if (Time.now - start > 0.5) || Rails.env.test?
              payload = { done: false, ai_topic_summary: { summarized_text: streamed_summary } }

              publish_update(topic, user, payload)
              start = Time.now
            end
          end

      publish_update(
        topic,
        user,
        AiTopicSummarySerializer.new(summary, { scope: guardian }).as_json.merge(done: true),
      )
    end

    private

    def publish_update(topic, user, payload)
      MessageBus.publish("/discourse-ai/summaries/topic/#{topic.id}", payload, user_ids: [user.id])
    end
  end
end
