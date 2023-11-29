# frozen_string_literal: true

module DiscourseAi
  module NSFW
    class EntryPoint
      def inject_into(plugin)
        nsfw_detection_cb =
          Proc.new do |post|
            if SiteSetting.ai_nsfw_detection_enabled &&
                 DiscourseAi::NSFW::Classification.new.can_classify?(post)
              Jobs.enqueue(:evaluate_post_uploads, post_id: post.id)
            end
          end

        plugin.on(:post_created, &nsfw_detection_cb)
        plugin.on(:post_edited, &nsfw_detection_cb)
      end
    end
  end
end
