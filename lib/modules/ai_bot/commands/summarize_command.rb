#frozen_string_literal: true

module DiscourseAi::AiBot::Commands
  class SummarizeCommand < Command
    class << self
      def name
        "summarize"
      end

      def desc
        "!summarize TOPIC_ID GUIDANCE - will summarize a topic attempting to answer question in guidance"
      end
    end

    def result_name
      "summary"
    end

    def standalone?
      true
    end

    def low_cost?
      true
    end

    def description_args
      { url: "#{Discourse.base_path}/t/-/#{@last_topic_id}", title: @last_topic_title || "" }
    end

    def process(instructions)
      topic_id, guidance = instructions.split(" ", 2)

      @last_topic_id = topic_id

      topic_id = topic_id.to_i
      topic = nil
      if topic_id > 0
        topic = Topic.find_by(id: topic_id)
        topic = nil if !topic || !Guardian.new.can_see?(topic)
      end

      rows = []

      if topic
        @last_topic_title = topic.title
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
