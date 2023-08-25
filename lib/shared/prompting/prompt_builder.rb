# frozen_string_literal: true

module DiscourseAi
  module Prompting
    class PromptBuilder
      def initialize(tokenizer:, max_tokens:)
        @tokenizer = tokenizer
        @max_tokens = max_tokens
        @contents = []
      end

      def full?
      end

      def <<(content:, type:, user: nil)
        validate_type(type)

        @contents << { content: content, type: type, user: user }
      end

      def unshift(content:, type:, user: nil)
        validate_type(type)

        @contents.unshift(content: content, type: type, user: user)
      end

      def generate
        raise NotImplemented
      end

      def validate_type(type)
        if !%i[system assistant user].include?(type)
          raise ArgumentError, "type must be one of :system, :assistant, :user"
        end
      end
    end
  end
end
