#frozen_string_literal: true

module DiscourseAi::AiBot::Commands
  class TimeCommand < Command
    def name
      "time"
    end

    def process(post, timezone)
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
