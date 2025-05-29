# frozen_string_literal: true

module DiscourseAi
  module Translation
    class PostLocalizer
      def self.localize(post, target_locale = I18n.locale)
        return if post.blank? || target_locale.blank? || post.locale == target_locale.to_s
        target_locale_sym = target_locale.to_s.sub("-", "_").to_sym

        translated_raw =
          ContentSplitter
            .split(post.raw)
            .map { |chunk| PostRawTranslator.new(chunk, target_locale_sym).translate }
            .join("")

        localization =
          PostLocalization.find_or_initialize_by(post_id: post.id, locale: target_locale_sym.to_s)

        localization.raw = translated_raw
        localization.cooked = PrettyText.cook(translated_raw)
        localization.post_version = post.version
        localization.localizer_user_id = Discourse.system_user.id
        localization.save!
        localization
      end
    end
  end
end
