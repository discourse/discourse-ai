# frozen_string_literal: true

module DiscourseAi
  module Translation
    class LocaleNormalizer
      # Normalizes locale string, matching the list of I18n.locales where possible
      # @param locale [String,Symbol] the locale to normalize
      # @return [String] the normalized locale
      def self.normalize_to_i18n(locale)
        return nil if locale.blank?
        locale = locale.to_s.gsub("-", "_")

        i18n_pairs.each { |downcased, value| return value if locale.downcase == downcased }

        locale
      end

      private

      def self.i18n_pairs
        # they should look like this for the input to match against:
        # {
        #   "lowercased" => "actual",
        #   "en" => "en",
        #   "zh_cn" => "zh_CN",
        #   "zh" => "zh_CN",
        # }
        @locale_map ||=
          I18n
            .available_locales
            .reduce({}) do |output, sym|
              locale = sym.to_s
              output[locale.downcase] = locale
              if locale.include?("_")
                short = locale.split("_").first
                output[short] = locale if output[short].blank?
              end
              output
            end
      end
    end
  end
end
