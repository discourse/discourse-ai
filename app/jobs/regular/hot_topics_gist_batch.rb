# frozen_string_literal: true

module ::Jobs
  class HotTopicsGistBatch < ::Jobs::Base
    def execute(args)
      return if !SiteSetting.discourse_ai_enabled
      return if !SiteSetting.ai_summarization_enabled
      return if !SiteSetting.ai_summarize_hot_topics_list

      Topic
        .joins("JOIN topic_hot_scores on topics.id = topic_hot_scores.topic_id")
        .order("topic_hot_scores.score DESC")
        .limit(100)
        .each do |topic|
          summarizer = DiscourseAi::Summarization.topic_gist(topic)
          gist = summarizer.existing_summary

          summarizer.delete_cached_summaries! if gist && gist.outdated

          summarizer.summarize(Discourse.system_user)
        end
    end
  end
end
