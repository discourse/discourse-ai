# frozen_string_literal: true

module DiscourseAi
  module Translation
    class EntryPoint
      def inject_into(plugin)
        plugin.on(:post_process_cooked) do |_, post|
          if SiteSetting.discourse_ai_enabled && SiteSetting.ai_translation_enabled
            Jobs.enqueue(:detect_translate_post, post_id: post.id)
          end
        end

        plugin.on(:topic_created) do |topic|
          if SiteSetting.discourse_ai_enabled && SiteSetting.ai_translation_enabled
            Jobs.enqueue(:detect_translate_topic, topic_id: topic.id)
          end
        end

        plugin.on(:post_edited) do |post, topic_changed|
          if SiteSetting.discourse_ai_enabled && SiteSetting.ai_translation_enabled && topic_changed
            Jobs.enqueue(:detect_translate_topic, topic_id: post.topic_id)
          end
        end
      end
    end
  end
end
