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
        plugin.register_svg_icon("discourse-sparkles")
      end
    end
  end
end
