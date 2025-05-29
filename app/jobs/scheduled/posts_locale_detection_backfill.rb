# frozen_string_literal: true

module Jobs
  class PostsLocaleDetectionBackfill < ::Jobs::Scheduled
    every 5.minutes
    sidekiq_options retry: false
    cluster_concurrency 1

    def execute(args)
      return if !SiteSetting.discourse_ai_enabled
      return if !SiteSetting.ai_translation_enabled
      return if SiteSetting.ai_translation_backfill_rate == 0

      posts =
        Post
          .where(locale: nil)
          .where(deleted_at: nil)
          .where("posts.user_id > 0")
          .where.not(raw: [nil, ""])

      if SiteSetting.ai_translation_backfill_limit_to_public_content
        public_categories = Category.where(read_restricted: false).pluck(:id)
        posts =
          posts
            .joins(:topic)
            .where(topics: { category_id: public_categories })
            .where(topics: { archetype: "regular" })
      end

      if SiteSetting.ai_translation_backfill_max_age_days > 0
        posts =
          posts.where(
            "posts.created_at > ?",
            SiteSetting.ai_translation_backfill_max_age_days.days.ago,
          )
      end

      posts = posts.order(updated_at: :desc).limit(SiteSetting.ai_translation_backfill_rate)
      return if posts.empty?

      posts.each do |post|
        begin
          DiscourseAi::Translation::PostLocaleDetector.detect_locale(post)
        rescue FinalDestination::SSRFDetector::LookupFailedError
          # do nothing, there are too many sporadic lookup failures
        rescue => e
          DiscourseAi::Translation::VerboseLogger.log(
            "Failed to detect post #{post.id}'s locale: #{e.message}",
          )
        end
      end

      DiscourseAi::Translation::VerboseLogger.log("Detected #{posts.size} post locales")
    end
  end
end
