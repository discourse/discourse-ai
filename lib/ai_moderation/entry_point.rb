# frozen_string_literal: true

module DiscourseAi
  module AiModeration
    class EntryPoint
      def inject_into(plugin)
        plugin.on(:post_created) { |post| SpamScanner.new_post(post) }
        plugin.on(:post_edited) { |post| SpamScanner.edited_post(post) }
        plugin.on(:post_process_cooked) { |_doc, post| SpamScanner.after_cooked_post(post) }

        plugin.on(:site_setting_changed) do |name, _old_value, new_value|
          SpamScanner.ensure_flagging_user! if name == :ai_spam_detection_enabled && new_value
        end

        custom_filter = [
          :ai_spam_false_negative,
          Proc.new do |results, value|
            if value
              results.where(<<~SQL)
              EXISTS (
                SELECT 1 FROM ai_spam_logs
                WHERE NOT is_spam
                AND post_id = target_id AND target_type = 'Post'
              )
            SQL
            else
              results
            end
          end,
        ]

        Reviewable.add_custom_filter(custom_filter)
      end
    end
  end
end
