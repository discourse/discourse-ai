# frozen_string_literal: true

module Jobs
  class TopicLocalizationBackfill < ::Jobs::Scheduled
    every 5.minutes
    cluster_concurrency 1

    def execute(args)
      return if !SiteSetting.discourse_ai_enabled
      return if !SiteSetting.ai_translation_enabled

      return if SiteSetting.content_localization_supported_locales.blank?
      limit = SiteSetting.ai_translation_backfill_hourly_rate / (60 / 5) # this job runs in 5-minute intervals
      return if limit == 0

      Jobs.enqueue(:localize_topics, limit:)
    end
  end
end
