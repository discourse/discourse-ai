# frozen_string_literal: true

module ::DiscourseAI
  module Toxicity
    class EventHandler
      class << self
        def handle_post_async(post)
          return if bypass?(post)
          Jobs.enqueue(:toxicity_classify_post, post_id: post.id)
        end

        def handle_chat_async(chat_message)
          return if bypass?(chat_message)
          Jobs.enqueue(:toxicity_classify_chat_message, chat_message_id: chat_message.id)
        end

        def bypass?(content)
          !SiteSetting.ai_toxicity_enabled || group_bypass?(content.user)
        end

        def group_bypass?(user)
          user.groups.pluck(:id).intersection(SiteSetting.disorder_groups_bypass_map).present?
        end
      end
    end
  end
end
