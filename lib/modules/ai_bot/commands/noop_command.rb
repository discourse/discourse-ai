#frozen_string_literal: true

module DiscourseAi::AiBot::Commands
  class NoopCommand < Command
    class << self
      def name
        "noop"
      end

      def desc
        "!noop - does nothing, catch all command when you do not know how to triage"
      end
    end

    def post_raw_details
      nil
    end

    def pre_raw_details
      nil
    end

    def process
      nil
    end
  end
end
