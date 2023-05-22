#frozen_string_literal: true

module DiscourseAi::AiBot::Commands
  class TagsCommand < Command
    class << self
      def name
        "tags"
      end

      def desc
        "!tags - will list the 100 most popular tags on the current discourse instance"
      end
    end

    def result_name
      "results"
    end

    def description_args
      { count: @last_count || 0 }
    end

    def process(_args)
      column_names = { name: "Name", public_topic_count: "Topic Count" }

      tags =
        Tag
          .where("public_topic_count > 0")
          .order(public_topic_count: :desc)
          .limit(100)
          .pluck(*column_names.keys)

      @last_count = tags.length

      format_results(tags, column_names.values)
    end
  end
end
