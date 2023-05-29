# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class EntryPoint
      def load_files
        require_relative "strategies/anthropic"
        require_relative "strategies/discourse_ai"
        require_relative "strategies/open_ai"
      end

      def inject_into(plugin)
        [Strategies::OpenAi, Strategies::DiscourseAi, Strategies::Anthropic].each do |strategy|
          plugin.register_summarization_strategy(strategy)
        end
      end
    end
  end
end
