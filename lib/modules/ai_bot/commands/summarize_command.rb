#frozen_string_literal: true

module DiscourseAi::AiBot::Commands
  class SummarizeCommand < Command
    def result_name
      "summary"
    end

    def name
      "summarize"
    end

    def standalone?
      true
    end

    def low_cost?
      true
    end

    def process(instructions)
      topic_id, guidance = instructions.split(" ", 2)

      topic_id = topic_id.to_i
      topic = nil
      if topic_id > 0
        topic = Topic.find_by(id: topic_id)
        topic = nil if !topic || !Guardian.new.can_see?(topic)
      end

      rows = []

      if topic
        if guidance.present?
          rows << ["Given: #{guidance}"]
          rows << ["Summarise: #{topic.title}"]
          Post
            .joins(:user)
            .where(topic_id: topic.id)
            .order(:post_number)
            .limit(50)
            .pluck(:raw, :username)
            .each { |raw, username| rows << ["#{username} said: #{raw}"] }
        end
      end

      if rows.blank?
        "Say: No topic found!"
      else
        "#{rows.join("\n")}"[0..2000]
      end
    end
  end
end
