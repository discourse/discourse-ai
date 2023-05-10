# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class EntryPoint
      GPT4_ID = -110
      GPT3_5_TURBO_ID = -111
      CLAUDE_V1_ID = -112
      BOTS = [
        [GPT4_ID, "gpt4_bot"],
        [GPT3_5_TURBO_ID, "gpt3.5_bot"],
        [CLAUDE_V1_ID, "claude_v1_bot"],
      ]

      def load_files
        require_relative "jobs/regular/create_ai_reply"
        require_relative "bot"
        require_relative "anthropic_bot"
        require_relative "open_ai_bot"
      end

      def inject_into(plugin)
        plugin.register_seedfu_fixtures(
          Rails.root.join("plugins", "discourse-ai", "db", "fixtures", "ai_bot"),
        )

        plugin.on(:post_created) do |post|
          bot_ids = BOTS.map(&:first)

          if post.topic.private_message? && !bot_ids.include?(post.user_id)
            if (SiteSetting.ai_bot_allowed_groups_map & post.user.group_ids).present?
              bot_id = post.topic.topic_allowed_users.where(user_id: bot_ids).first&.user_id

              Jobs.enqueue(:create_ai_reply, post_id: post.id, bot_user_id: bot_id) if bot_id
            end
          end
        end
      end
    end
  end
end
