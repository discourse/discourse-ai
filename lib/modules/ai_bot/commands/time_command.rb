#frozen_string_literal: true

module DiscourseAi::AiBot::Commands
  class TimeCommand < Command
    def result_name
      "time"
    end

    def name
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
