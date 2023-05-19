#frozen_string_literal: true

module DiscourseAi::AiBot::Commands
  class TimeCommand < Command
    class << self
      def name
        "time"
      end

      def desc
        "!time RUBY_COMPATIBLE_TIMEZONE - will generate the time in a timezone"
      end
    end

    def result_name
      "time"
    end

    def process(timezone)
      time =
        begin
          Time.now.in_time_zone(timezone)
        rescue StandardError
          nil
        end
      time = Time.now if !time
      time.to_s
    end
  end
end
