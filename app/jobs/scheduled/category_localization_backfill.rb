# frozen_string_literal: true

module Jobs
  class CategoryLocalizationBackfill < ::Jobs::Scheduled
    every 12.hours
    cluster_concurrency 1

    def execute(args)
      return if !SiteSetting.discourse_ai_enabled
      return if !SiteSetting.ai_translation_enabled
      return if SiteSetting.experimental_content_localization_supported_locales.blank?

      Jobs.enqueue(:localize_categories)
    end
  end
end
