# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class EntryPoint
      def load_files
        require_relative "models/base"
        require_relative "models/anthropic"
        require_relative "models/discourse"
        require_relative "models/open_ai"

        require_relative "strategies/fold_content"
        require_relative "strategies/truncate_content"
      end

      def inject_into(plugin)
        foldable_models = [
          Models::OpenAi.new("gpt-4", max_tokens: 8192),
          Models::OpenAi.new("gpt-4-32k", max_tokens: 32_768),
          Models::OpenAi.new("gpt-3.5-turbo", max_tokens: 4096),
          Models::OpenAi.new("gpt-3.5-turbo-16k", max_tokens: 16_384),
          Models::Discourse.new("long-t5-tglobal-base-16384-book-summary", max_tokens: 16_384),
          Models::Anthropic.new("claude-v1", max_tokens: 9000),
          Models::Anthropic.new("claude-v1-100k", max_tokens: 100_000),
          Models::Anthropic.new("claude-2", max_tokens: 100_000),
        ]

        foldable_models.each do |model|
          plugin.register_summarization_strategy(Strategies::FoldContent.new(model))
        end

        truncable_models = [
          Models::Discourse.new("bart-large-cnn-samsum", max_tokens: 1024),
          Models::Discourse.new("flan-t5-base-samsum", max_tokens: 512),
        ]

        truncable_models.each do |model|
          plugin.register_summarization_strategy(Strategies::TruncateContent.new(model))
        end
      end
    end
  end
end
