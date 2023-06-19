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

      def parameters
        [
          Parameter.new(
            name: "timezone",
            description: "Ruby compatible timezone",
            type: "string",
            required: true,
          ),
        ]
      end
    end

    def result_name
      "time"
    end

    def description_args
      { timezone: @last_timezone, time: @last_time }
    end

    def process(args)
      timezone = JSON.parse(args)["timezone"]

      time =
        begin
          Time.now.in_time_zone(timezone)
        rescue StandardError
          nil
        end
      time = Time.now if !time

      @last_timezone = timezone
      @last_time = time.to_s

      time.to_s
    end
  end
end
