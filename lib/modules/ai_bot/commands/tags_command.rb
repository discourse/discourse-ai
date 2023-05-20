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
      info = +"Name, Topic Count\n"
      @last_count = 0
      Tag
        .where("public_topic_count > 0")
        .order(public_topic_count: :desc)
        .limit(100)
        .pluck(:name, :public_topic_count)
        .each do |name, count|
          @last_count += 1
          info << "#{name}, #{count}\n"
        end
      info
    end
  end
end
