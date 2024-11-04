# frozen_string_literal: true

module ::Jobs
  class SummariesBackfill < ::Jobs::Scheduled
    every 5.minutes
    cluster_concurrency 1

    def execute(_args)
      return if !SiteSetting.discourse_ai_enabled
      return if !SiteSetting.ai_summarization_enabled
      return if SiteSetting.ai_summary_backfill_maximum_topics_per_hour.zero?

      # Split budget in 12 intervals, but make sure is at least one.
      limit_per_job = [SiteSetting.ai_summary_backfill_maximum_topics_per_hour, 12].max / 12
      budget = [current_budget, limit_per_job].min

      backfill_candidates
        .limit(budget)
        .each do |topic|
          DiscourseAi::Summarization.topic_summary(topic).force_summarize(Discourse.system_user)
        end
    end

    def backfill_candidates
      Topic
        .where("topics.word_count >= ?", SiteSetting.ai_summary_backfill_minimum_word_count)
        .joins(
          "LEFT OUTER JOIN ai_summaries ais ON topics.id = ais.target_id AND ais.target_type = 'Topic'",
        )
        .where(
          "ais.id IS NULL OR UPPER(ais.content_range) < topics.highest_post_number + 1",
        ) # (1..1) gets stored ad (1..2).
        .order("ais.created_at DESC NULLS FIRST, topics.last_posted_at DESC")
    end

    def current_budget
      base_budget = SiteSetting.ai_summary_backfill_maximum_topics_per_hour
      used_budget = AiSummary.complete.system.where("created_at > ?", 1.hour.ago).count

      base_budget - used_budget
    end
  end
end
