#frozen_string_literal: true

module DiscourseAi::AiBot::Commands
  class TagsCommand < Command
    def result_name
      "results"
    end

    def name
      "tags"
    end

    def process(_args)
      info = +"Name, Topic Count\n"
      Tag
        .where("public_topic_count > 0")
        .order(public_topic_count: :desc)
        .limit(100)
        .pluck(:name, :public_topic_count)
        .each { |name, count| info << "#{name}, #{count}\n" }
      info
    end
  end
end
