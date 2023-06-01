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
        [
          Strategies::OpenAi.new("gpt-4"),
          Strategies::OpenAi.new("gpt-3.5-turbo"),
          Strategies::DiscourseAi.new("bart-large-cnn-samsum"),
          Strategies::DiscourseAi.new("flan-t5-base-samsum"),
          Strategies::DiscourseAi.new("long-t5-tglobal-base-16384-book-summary"),
          Strategies::Anthropic.new("claude-v1"),
          Strategies::Anthropic.new("claude-v1-100k"),
        ].each { |strategy| plugin.register_summarization_strategy(strategy) }
      end
    end
  end
end
