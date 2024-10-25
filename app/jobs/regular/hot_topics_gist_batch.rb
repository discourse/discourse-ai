# frozen_string_literal: true

module ::Jobs
  class HotTopicsGistBatch < ::Jobs::Base
    def execute(_args)
      return if !SiteSetting.discourse_ai_enabled
      return if !SiteSetting.ai_summarization_enabled
      return if SiteSetting.ai_summarize_max_hot_topics_gists_per_batch.zero?

      Topic
        .joins("JOIN topic_hot_scores on topics.id = topic_hot_scores.topic_id")
        .order("topic_hot_scores.score DESC")
        .limit(SiteSetting.ai_summarize_max_hot_topics_gists_per_batch)
        .each do |topic|
          summarizer = DiscourseAi::Summarization.topic_gist(topic)
          gist = summarizer.existing_summary

          summarizer.force_summarize(Discourse.system_user) if gist.blank? || gist.outdated
        end
    end
  end
end
