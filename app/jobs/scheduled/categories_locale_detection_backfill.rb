# frozen_string_literal: true

module Jobs
  class CategoriesLocaleDetectionBackfill < ::Jobs::Scheduled
    every 1.hour
    sidekiq_options retry: false
    cluster_concurrency 1

    def execute(args)
      return if !SiteSetting.discourse_ai_enabled
      return if !SiteSetting.ai_translation_enabled
      return if SiteSetting.ai_translation_backfill_rate == 0

      categories = Category.where(locale: nil)

      if SiteSetting.ai_translation_backfill_limit_to_public_content
        categories = categories.where(read_restricted: false)
      end

      categories = categories.limit(SiteSetting.ai_translation_backfill_rate)
      return if categories.empty?

      categories.each do |category|
        begin
          DiscourseAi::Translation::CategoryLocaleDetector.detect_locale(category)
        rescue FinalDestination::SSRFDetector::LookupFailedError
        rescue => e
          DiscourseAi::Translation::VerboseLogger.log(
            "Failed to detect category #{category.id}'s locale: #{e.message}",
          )
        end
      end

      DiscourseAi::Translation::VerboseLogger.log("Detected #{categories.size} category locales")
    end
  end
end
