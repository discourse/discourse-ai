# frozen_string_literal: true

module Jobs
  class DetectTranslateTopic < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return if !SiteSetting.discourse_ai_enabled
      return if !SiteSetting.ai_translation_enabled
      return if args[:topic_id].blank?

      topic = Topic.find_by(id: args[:topic_id])
      if topic.blank? || topic.title.blank? || topic.deleted_at.present? || topic.user_id <= 0
        return
      end

      if SiteSetting.ai_translation_backfill_limit_to_public_content
        return if topic.category&.read_restricted?
      end

      begin
        detected_locale = DiscourseAi::Translation::TopicLocaleDetector.detect_locale(topic)
      rescue FinalDestination::SSRFDetector::LookupFailedError
        # this job is non-critical
        # the backfill job will handle failures
        return
      end

      locales = SiteSetting.experimental_content_localization_supported_locales.split("|")
      return if locales.blank?

      locales.each do |locale|
        next if locale == detected_locale

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
    end
  end
end
