# frozen_string_literal: true
module DiscourseAI
  module AIHelper
    class EntryPoint
      def load_files
      end

      def inject_into(plugin)
        plugin.register_svg_icon("magic")
      end
    end
  end
end
