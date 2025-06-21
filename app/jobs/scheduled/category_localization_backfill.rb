# frozen_string_literal: true

module Jobs
  class CategoryLocalizationBackfill < ::Jobs::Scheduled
    every 1.hour
    cluster_concurrency 1

    def execute(args)
      return if !SiteSetting.discourse_ai_enabled
      return if !SiteSetting.ai_translation_enabled
      return if SiteSetting.content_localization_supported_locales.blank?
      limit = SiteSetting.ai_translation_backfill_hourly_rate
      return if limit == 0

      Jobs.enqueue(:localize_categories, limit:)
    end
  end
end
