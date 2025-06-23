# frozen_string_literal: true

module Jobs
  class LocalizePosts < ::Jobs::Base
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
        posts =
          Post
            .joins(
              "LEFT JOIN post_localizations pl ON pl.post_id = posts.id AND pl.locale = #{ActiveRecord::Base.connection.quote(locale)}",
            )
            .where(deleted_at: nil)
            .where("posts.user_id > 0")
            .where.not(raw: [nil, ""])
            .where.not(locale: nil)
            .where.not(locale: locale)
            .where("pl.id IS NULL")

        posts = posts.joins(:topic)

        if SiteSetting.ai_translation_backfill_limit_to_public_content
          # exclude all PMs
          # and only include posts from public categories
          posts =
            posts
              .where.not(topics: { archetype: Archetype.private_message })
              .where(topics: { category_id: Category.where(read_restricted: false).select(:id) })
        else
          # all regular topics, and group PMs
          posts =
            posts.where(
              "topics.archetype != ? OR topics.id IN (SELECT topic_id FROM topic_allowed_groups)",
              Archetype.private_message,
            )
        end

        if SiteSetting.ai_translation_backfill_max_age_days > 0
          posts =
            posts.where(
              "posts.created_at > ?",
              SiteSetting.ai_translation_backfill_max_age_days.days.ago,
            )
        end

        posts = posts.order(updated_at: :desc).limit(limit)

        next if posts.empty?

        posts.each do |post|
          begin
            DiscourseAi::Translation::PostLocalizer.localize(post, locale)
          rescue FinalDestination::SSRFDetector::LookupFailedError
            # do nothing, there are too many sporadic lookup failures
          rescue => e
            DiscourseAi::Translation::VerboseLogger.log(
              "Failed to translate post #{post.id} to #{locale}: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
            )
          end
        end

        DiscourseAi::Translation::VerboseLogger.log("Translated #{posts.size} posts to #{locale}")
      end
    end
  end
end
