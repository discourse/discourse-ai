# frozen_string_literal: true
module DiscourseAi
  module AiHelper
    class EntryPoint
      def inject_into(plugin)
        plugin.register_seedfu_fixtures(
          Rails.root.join("plugins", "discourse-ai", "db", "fixtures", "ai_helper"),
        )

        additional_icons = %w[spell-check language images]
        additional_icons.each { |icon| plugin.register_svg_icon(icon) }

        plugin.on(:chat_message_created) do |message, channel, user, extra|
          next unless SiteSetting.composer_ai_helper_enabled
          next unless SiteSetting.ai_helper_automatic_chat_thread_title
          next unless extra[:thread].present?
          next unless extra[:thread].title.blank?

          reply_count = extra[:thread].replies.count

          if reply_count.between?(1, 4)
            ::Jobs.enqueue_in(
              SiteSetting.ai_helper_automatic_chat_thread_title_delay.minutes,
              :generate_chat_thread_title,
              thread_id: extra[:thread].id,
            )
          elsif reply_count >= 5
            ::Jobs.enqueue(:generate_chat_thread_title, thread_id: extra[:thread].id)
          end
        end

        plugin.add_to_serializer(
          :current_user,
          :ai_helper_prompts,
          include_condition: -> do
            SiteSetting.composer_ai_helper_enabled && scope.authenticated? &&
              scope.user.in_any_groups?(SiteSetting.ai_helper_allowed_groups_map)
          end,
        ) do
          ActiveModel::ArraySerializer.new(
            DiscourseAi::AiHelper::Assistant.new.available_prompts,
            root: false,
          )
        end
      end
    end
  end
end
