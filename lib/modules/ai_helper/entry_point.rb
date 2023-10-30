# frozen_string_literal: true
module DiscourseAi
  module AiHelper
    class EntryPoint
      def load_files
        require_relative "chat_thread_titler"
        require_relative "jobs/regular/generate_chat_thread_title"
        require_relative "llm_prompt"
        require_relative "painter"
        require_relative "semantic_categorizer"
        require_relative "topic_helper"
      end

      def inject_into(plugin)
        plugin.register_seedfu_fixtures(
          Rails.root.join("plugins", "discourse-ai", "db", "fixtures", "ai_helper"),
        )

        additional_icons = %w[spell-check language]
        additional_icons.each { |icon| plugin.register_svg_icon(icon) }

        plugin.on(:chat_thread_created) do |thread|
          return unless SiteSetting.composer_ai_helper_enabled
          return unless SiteSetting.ai_helper_automatic_chat_thread_title
          Jobs.enqueue_in(
            SiteSetting.ai_helper_automatic_chat_thread_title_delay.minutes,
            :generate_chat_thread_title,
            thread_id: thread.id,
          )
        end
      end
    end
  end
end
