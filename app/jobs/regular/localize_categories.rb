# frozen_string_literal: true

module Jobs
  class LocalizeCategories < ::Jobs::Base
    cluster_concurrency 1
    sidekiq_options retry: false

    BATCH_SIZE = 50

    def execute(args)
      return if !SiteSetting.discourse_ai_enabled
      return if !SiteSetting.ai_translation_enabled

      locales = SiteSetting.experimental_content_localization_supported_locales.split("|")
      return if locales.blank?

      cat_id = args[:from_category_id] || Category.order(:id).first&.id
      last_id = nil

      categories = Category.where("id >= ?", cat_id).order(:id).limit(BATCH_SIZE)
      return if categories.empty?

      categories.each do |category|
        if SiteSetting.ai_translation_backfill_limit_to_public_content && category.read_restricted?
          last_id = category.id
          next
        end

        CategoryLocalization.transaction do
          locales.each do |locale|
            next if CategoryLocalization.exists?(category_id: category.id, locale: locale)
            begin
              DiscourseAi::Translation::CategoryLocalizer.localize(category, locale)
            rescue FinalDestination::SSRFDetector::LookupFailedError
              # do nothing, there are too many sporadic lookup failures
            rescue => e
              DiscourseAi::Translation::VerboseLogger.log(
                "Failed to translate category #{category.id} to #{locale}: #{e.message}",
              )
            end
          end
        end
        last_id = category.id
      end

      if categories.size == BATCH_SIZE
        Jobs.enqueue_in(10.seconds, :localize_categories, from_category_id: last_id + 1)
      end
    end
  end
end
