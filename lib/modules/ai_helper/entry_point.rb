# frozen_string_literal: true
module DiscourseAi
  module AiHelper
    class EntryPoint
      def load_files
        require_relative "open_ai_prompt"
      end

      def inject_into(plugin)
        plugin.register_svg_icon("magic")
      end
    end
  end
end
