# frozen_string_literal: true

module DiscourseAi
  module AiModeration
    class EntryPoint
      def inject_into(plugin)
        plugin.on(:post_created) do |post|
          SpamScanner.new_post(post)
        end

        plugin.on(:post_edited) do |post|
          SpamScanner.edited_post(post)
        end
      end
    end
  end
end
