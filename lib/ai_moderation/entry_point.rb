# frozen_string_literal: true

module DiscourseAi
  module AiModeration
    class EntryPoint
      def inject_into(plugin)
        plugin.on(:post_created) { |post| SpamScanner.new_post(post) }
        plugin.on(:post_edited) { |post| SpamScanner.edited_post(post) }
        plugin.on(:post_process_cooked) { |_doc, post| SpamScanner.after_cooked_post(post) }
      end
    end
  end
end
