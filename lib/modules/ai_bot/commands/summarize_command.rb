#frozen_string_literal: true

module DiscourseAi::AiBot::Commands
  class SummarizeCommand < Command
    class << self
      def name
        "summarize"
      end

      def desc
        "Will summarize a topic attempting to answer question in guidance"
      end

      def parameters
        [
          Parameter.new(
            name: "topic_id",
            description: "The discourse topic id to summarize",
            type: "integer",
            required: true,
          ),
          Parameter.new(
            name: "guidance",
            description: "Special guidance on how to summarize the topic",
            type: "string",
          ),
        ]
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

      @last_summary = nil

      if topic
        @last_topic_title = topic.title

        posts =
          Post
            .where(topic_id: topic.id)
            .where("post_type in (?)", [Post.types[:regular], Post.types[:small_action]])
            .where("not hidden")
            .order(:post_number)

        columns = ["posts.id", :post_number, :raw, :username]

        current_post_numbers = posts.limit(5).pluck(:post_number)
        current_post_numbers += posts.reorder("posts.score desc").limit(50).pluck(:post_number)
        current_post_numbers += posts.reorder("post_number desc").limit(5).pluck(:post_number)

        data =
          Post
            .where(topic_id: topic.id)
            .joins(:user)
            .where("post_number in (?)", current_post_numbers)
            .order(:post_number)
            .pluck(*columns)

        @last_summary = summarize(data, guidance, topic)
      end

      if !@last_summary
        "Say: No topic found!"
      else
        "Topic summarized"
      end
    end

    def custom_raw
      @last_summary || I18n.t("discourse_ai.ai_bot.topic_not_found")
    end

    def chain_next_response
      false
    end

    def summarize(data, guidance, topic)
      text = +""
      data.each do |id, post_number, raw, username|
        text << "(#{post_number} #{username} said: #{raw}"
      end

      summaries = []
      current_section = +""
      split = []

      text
        .split(/\s+/)
        .each_slice(20) do |slice|
          current_section << " "
          current_section << slice.join(" ")

          # somehow any more will get closer to limits
          if bot.tokenize(current_section).length > 2500
            split << current_section
            current_section = +""
          end
        end

      split << current_section if current_section.present?

      split = split[0..3] + split[-3..-1] if split.length > 5

      split.each do |section|
        # TODO progress meter
        summary =
          generate_gpt_summary(
            section,
            topic: topic,
            context: "Guidance: #{guidance}\nYou are summarizing the topic: #{topic.title}",
          )
        summaries << summary
      end

      if summaries.length > 1
        messages = []
        messages << { role: "system", content: "You are a helpful bot" }
        messages << {
          role: "user",
          content:
            "concatenated the disjoint summaries, creating a cohesive narrative:\n#{summaries.join("\n")}}",
        }
        bot.submit_prompt(messages, temperature: 0.6, max_tokens: 500, prefer_low_cost: true).dig(
          :choices,
          0,
          :message,
          :content,
        )
      else
        summaries.first
      end
    end

    def generate_gpt_summary(text, topic:, context: nil, length: nil)
      length ||= 400

      prompt = <<~TEXT
        #{context}
        Summarize the following in #{length} words:

        #{text}
      TEXT

      system_prompt = <<~TEXT
        You are a summarization bot.
        You effectively summarise any text.
        You condense it into a shorter version.
        You understand and generate Discourse forum markdown.
        Try generating links as well the format is #{topic.url}/POST_NUMBER. eg: [ref](#{topic.url}/77)
      TEXT

      messages = [{ role: "system", content: system_prompt }]
      messages << { role: "user", content: prompt }

      result =
        bot.submit_prompt(messages, temperature: 0.6, max_tokens: length, prefer_low_cost: true)
      result.dig(:choices, 0, :message, :content)
    end
  end
end
