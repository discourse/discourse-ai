# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Models
      class Base
        def initialize(model_name, max_tokens:)
          @model_name = model_name
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

        def model
          model_name.split(":").last
        end

        attr_reader :model_name, :max_tokens

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
