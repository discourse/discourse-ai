# frozen_string_literal: true

module DiscourseAi
  module Translation
    class CategoryLocalizer
      def self.localize(category, target_locale = I18n.locale)
        return if category.blank? || target_locale.blank?

        target_locale_sym = target_locale.to_s.sub("-", "_").to_sym

        translated_name = ShortTextTranslator.new(category.name, target_locale_sym).translate
        translated_description =
          if category.description.present?
            PostRawTranslator.new(category.description, target_locale_sym).translate
          else
            ""
          end

        localization =
          CategoryLocalization.find_or_initialize_by(
            category_id: category.id,
            locale: target_locale_sym.to_s,
          )

        localization.name = translated_name
        localization.description = translated_description
        localization.save!
        localization
      end
    end
  end
end
