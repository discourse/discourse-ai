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
          posts =
            Post
              .joins(:user)
              .where(topic_id: topic.id)
              .where("post_type in (?)", [Post.types[:regular], Post.types[:small_action]])
              .where("not hidden")
              .order(:post_number)

          columns = ["posts.id", :post_number, :raw, :username]

          current = posts.limit(3).pluck(columns)

          current +=
            posts
              .where("posts.id not in(?)", current.map { |x| x[0] })
              .reorder("posts.score desc")
              .limit(10)
              .sort_by { |row| row[1] }

          current +=
            posts
              .where("posts.id not in(?)", current.map { |x| x[0] })
              .reorder("post_number desc")
              .limit(3)
              .pluck(columns)
              .reverse

          current.each do |id, post_number, raw, username|
            rows << ["(#{post_number} #{username} said: #{raw}"]
          end
        end
      end

      if rows.blank?
        "Say: No topic found!"
      else
        # TODO got to be way smarter about this and use tokens
        "#{rows.join("\n")}"[0..3000]
      end
    end
  end
end
