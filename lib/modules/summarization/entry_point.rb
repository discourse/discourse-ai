# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class EntryPoint
      def load_files
        require_relative "summary_generator"
      end

      def inject_into(plugin)
      end
    end
  end
end
