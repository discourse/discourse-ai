#frozen_string_literal: true

module DiscourseAi::AiBot::Commands
  class SearchCommand < Command
    def result_name
      "results"
    end

    def name
      "search"
    end

    def process(search_string)
      results =
        Search.execute(search_string.to_s, search_type: :full_page, guardian: Guardian.new())

      results.posts[0..10]
        .map do |p|
          {
            title: p.topic.title,
            url: p.url,
            raw_truncated: p.raw[0..250],
            excerpt: p.excerpt,
            created: p.created_at,
          }
        end
        .to_json
    end
  end
end
