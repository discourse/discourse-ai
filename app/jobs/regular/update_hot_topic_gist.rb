# frozen_string_literal: true

module ::Jobs
  class UpdateHotTopicGist < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return if !SiteSetting.discourse_ai_enabled
      return if !SiteSetting.ai_summarization_enabled
      return if SiteSetting.ai_summarize_max_hot_topics_gists_per_batch.zero?

      topic = Topic.find_by(id: args[:topic_id])
      return if topic.blank?

      return if !TopicHotScore.where(topic: topic).exists?

      summarizer = DiscourseAi::Summarization.topic_gist(topic)
      gist = summarizer.existing_summary
      return if gist.blank?
      return if !gist.outdated

      summarizer.force_summarize(Discourse.system_user)
    end
  end
end
