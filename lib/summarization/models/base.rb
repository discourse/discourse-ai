# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Models
      class Base
        def initialize(model, max_tokens:)
          @model = model
          @max_tokens = max_tokens
        end

        def correctly_configured?
          raise NotImplemented
        end

        def display_name
          raise NotImplemented
        end

        def configuration_hint
          raise NotImplemented
        end

        def available_tokens
          max_tokens - reserved_tokens
        end

        attr_reader :model, :max_tokens

        protected

        def reserved_tokens
          # Reserve tokens for the response and the base prompt
          # ~500 words
          700
        end
      end
    end
  end
end
