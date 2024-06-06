# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class SummarizationValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        strategy = DiscourseAi::Summarization::Models::Base.find_strategy(val)

        return true unless strategy

        strategy.correctly_configured?.tap { |is_valid| @strategy = strategy unless is_valid }
      end

      def error_message
        @strategy.configuration_hint
      end
    end
  end
end
