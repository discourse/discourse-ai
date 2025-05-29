# frozen_string_literal: true

module Jobs
  class DetectTranslatePost < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return if !SiteSetting.discourse_ai_enabled
      return if !SiteSetting.ai_translation_enabled
      return if args[:post_id].blank?

      post = Post.find_by(id: args[:post_id])
      return if post.blank? || post.raw.blank? || post.deleted_at.present? || post.user_id <= 0

      if SiteSetting.ai_translation_backfill_limit_to_public_content
        topic = post.topic
        if topic.blank? || topic.category&.read_restricted? ||
             topic.archetype == Archetype.private_message
          return
        end
      end

      begin
        detected_locale = DiscourseAi::Translation::PostLocaleDetector.detect_locale(post)
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
          DiscourseAi::Translation::PostLocalizer.localize(post, locale)
        rescue FinalDestination::SSRFDetector::LookupFailedError
          # do nothing, there are too many sporadic lookup failures
        rescue => e
          DiscourseAi::Translation::VerboseLogger.log(
            "Failed to translate post #{post.id} to #{locale}: #{e.message}",
          )
        end
      end
    end
  end
end
