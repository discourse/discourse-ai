# frozen_string_literal: true

module DiscourseAI
  module NSFW
    class EntryPoint
      def load_files
        require_relative "evaluation"
        require_relative "jobs/regular/evaluate_post_uploads"
      end

      def inject_into(plugin)
        nsfw_detection_cb =
          Proc.new do |post|
            if SiteSetting.ai_nsfw_detection_enabled
              Jobs.enqueue(:evaluate_post_uploads, post_id: post.id)
            end
          end

        plugin.on(:post_created, &nsfw_detection_cb)
        plugin.on(:post_edited, &nsfw_detection_cb)
      end
    end
  end
end
