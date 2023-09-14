# frozen_string_literal: true
module DiscourseAi
  module AiHelper
    class EntryPoint
      def load_files
        require_relative "llm_prompt"
        require_relative "semantic_categorizer"
        require_relative "painter"
      end

      def inject_into(plugin)
        plugin.register_seedfu_fixtures(
          Rails.root.join("plugins", "discourse-ai", "db", "fixtures", "ai_helper"),
        )

        additional_icons = %w[discourse-sparkles spell-check language]
        additional_icons.each { |icon| plugin.register_svg_icon(icon) }
      end
    end
  end
end
