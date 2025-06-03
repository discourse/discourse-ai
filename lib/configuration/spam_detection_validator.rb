# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class SpamDetectionValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        return true if Rails.env.test?
        return true if AiModerationSetting.spam
        # only validate when enabling setting
        return true if val == "f"

        false
      end

      def error_message
        I18n.t("discourse_ai.spam_detection.configuration_missing")
      end
    end
  end
end
