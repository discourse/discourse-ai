# frozen_string_literal: true

module DiscourseAi
  module Translation
    class TopicLocaleDetector
      def self.detect_locale(topic)
        return if topic.blank?

        text = topic.title.dup
        text << " #{topic.first_post.raw}" if topic.first_post.raw

        detected_locale = LanguageDetector.new(text).detect
        locale = LocaleNormalizer.normalize_to_i18n(detected_locale)
        topic.update_column(:locale, locale)
        locale
      end
    end
  end
end
