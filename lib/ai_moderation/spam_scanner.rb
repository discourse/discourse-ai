module DiscourseAi
  module AiModeration
    class SpamScanner
      def self.new_post(post)
        return if !enabled?
      end

      def self.edited_post(post)
        return if !enabled?
      end

      def self.enabled?
        SiteSetting.ai_spam_detection_enabled && SiteSetting.discourse_ai_enabled
      end
    end
  end
end
