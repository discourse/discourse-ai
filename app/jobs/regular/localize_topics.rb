# frozen_string_literal: true

module Jobs
  class LocalizeTopics < ::Jobs::Base
    cluster_concurrency 1
    sidekiq_options retry: false

    BATCH_SIZE = 50

    def execute(args)
      return if !SiteSetting.discourse_ai_enabled
      return if !SiteSetting.ai_translation_enabled

      locales = SiteSetting.experimental_content_localization_supported_locales.split("|")
      return if locales.blank?

      limit = args[:limit] || BATCH_SIZE

      locales.each do |locale|
        topics =
          Topic
            .joins(
              "LEFT JOIN topic_localizations tl ON tl.topic_id = topics.id AND tl.locale = #{ActiveRecord::Base.connection.quote(locale)}",
            )
            .where(deleted_at: nil)
            .where("topics.user_id > 0")
            .where.not(locale: nil)
            .where.not(locale: locale)
            .where("tl.id IS NULL")

        if SiteSetting.ai_translation_backfill_limit_to_public_content
          topics = topics.where(category_id: Category.where(read_restricted: false).select(:id))
        end

        if SiteSetting.ai_translation_backfill_max_age_days > 0
          topics =
            topics.where(
              "topics.created_at > ?",
              SiteSetting.ai_translation_backfill_max_age_days.days.ago,
            )
        end

        topics = topics.order(updated_at: :desc).limit(limit)

        next if topics.empty?

        topics.each do |topic|
          begin
            DiscourseAi::Translation::TopicLocalizer.localize(topic, locale)
          rescue FinalDestination::SSRFDetector::LookupFailedError
            # do nothing, there are too many sporadic lookup failures
          rescue => e
            DiscourseAi::Translation::VerboseLogger.log(
              "Failed to translate topic #{topic.id} to #{locale}: #{e.message}",
            )
          end
        end

        DiscourseAi::Translation::VerboseLogger.log("Translated #{topics.size} topics to #{locale}")
      end
    end
  end
end
