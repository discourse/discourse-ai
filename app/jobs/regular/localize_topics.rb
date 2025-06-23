# frozen_string_literal: true

module Jobs
  class LocalizeTopics < ::Jobs::Base
    cluster_concurrency 1
    sidekiq_options retry: false

    def execute(args)
      limit = args[:limit]
      raise Discourse::InvalidParameters.new(:limit) if limit.blank? || limit <= 0

      return if !SiteSetting.discourse_ai_enabled
      return if !SiteSetting.ai_translation_enabled

      locales = SiteSetting.content_localization_supported_locales.split("|")
      return if locales.blank?

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
          # exclude all PMs
          # and only include posts from public categories
          topics =
            topics
              .where.not(archetype: Archetype.private_message)
              .where(category_id: Category.where(read_restricted: false).select(:id))
        else
          # all regular topics, and group PMs
          topics =
            topics.where(
              "topics.archetype != ? OR topics.id IN (SELECT topic_id FROM topic_allowed_groups)",
              Archetype.private_message,
            )
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
              "Failed to translate topic #{topic.id} to #{locale}: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
            )
          end
        end

        DiscourseAi::Translation::VerboseLogger.log("Translated #{topics.size} topics to #{locale}")
      end
    end
  end
end
