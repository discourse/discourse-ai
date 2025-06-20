# frozen_string_literal: true

module Jobs
  class LocalizeCategories < ::Jobs::Base
    cluster_concurrency 1
    sidekiq_options retry: false

    def execute(args)
      limit = args[:limit]
      raise Discourse::InvalidParameters.new(:limit) if limit.nil?
      return if limit <= 0

      return if !SiteSetting.discourse_ai_enabled
      return if !SiteSetting.ai_translation_enabled
      locales = SiteSetting.content_localization_supported_locales.split("|")
      return if locales.blank?

      categories = Category.where("locale IS NOT NULL")

      if SiteSetting.ai_translation_backfill_limit_to_public_content
        categories = categories.where(read_restricted: false)
      end

      categories = categories.order(:id).limit(limit)
      return if categories.empty?

      remaining_limit = limit

      categories.each do |category|
        break if remaining_limit <= 0

        existing_locales = CategoryLocalization.where(category_id: category.id).pluck(:locale)
        missing_locales = locales - existing_locales - [category.locale]
        missing_locales.each do |locale|
          break if remaining_limit <= 0

          begin
            DiscourseAi::Translation::CategoryLocalizer.localize(category, locale)
          rescue FinalDestination::SSRFDetector::LookupFailedError
            # do nothing, there are too many sporadic lookup failures
          rescue => e
            DiscourseAi::Translation::VerboseLogger.log(
              "Failed to translate category #{category.id} to #{locale}: #{e.message}",
            )
          ensure
            remaining_limit -= 1
          end
        end

        if existing_locales.include?(category.locale)
          CategoryLocalization.find_by(category_id: category.id, locale: category.locale).destroy
        end
      end
    end
  end
end
