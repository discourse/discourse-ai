# frozen_string_literal: true

module DiscourseAi
  module AiModeration
    class EntryPoint
      def inject_into(plugin)
        plugin.on(:post_created) { |post| SpamScanner.new_post(post) }
        plugin.on(:post_edited) { |post| SpamScanner.edited_post(post) }
        plugin.on(:post_process_cooked) { |_doc, post| SpamScanner.after_cooked_post(post) }

        plugin.on(:site_setting_changed) do |name, _old_value, new_value|
          if name == :ai_spam_detection_enabled && new_value
            SpamScanner.ensure_flagging_user!
          end
        end
      end
    end
  end
end
