# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class EntryPoint
      AI_BOT_ID = -110

      def load_files
        require_relative "jobs/regular/create_ai_reply"
      end

      def inject_into(plugin)
        plugin.register_seedfu_fixtures(
          Rails.root.join("plugins", "discourse-ai", "db", "fixtures", "ai_bot"),
        )

        plugin.add_class_method(Discourse, :gpt_bot) do
          @ai_bots ||= {}
          current_db = RailsMultisite::ConnectionManagement.current_db
          @ai_bots[current_db] ||= User.find(AI_BOT_ID)
        end

        plugin.on(:post_created) do |post|
          if post.topic.private_message? && post.user_id != AI_BOT_ID &&
               post.topic.topic_allowed_users.exists?(user_id: Discourse.gpt_bot.id)
            in_allowed_group =
              SiteSetting.ai_bot_allowed_groups_map.any? do |group_id|
                post.user.group_ids.include?(group_id)
              end

            Jobs.enqueue(:create_ai_reply, post_id: post.id) if in_allowed_group
          end
        end
      end
    end
  end
end
