#frozen_string_literal: true

module DiscourseAi::AiBot::Commands
  class SearchCommand < Command
    class << self
      def name
        "search"
      end

      def desc
        "Will search topics in the current discourse instance, when rendering always prefer to link to the topics you find"
      end

      def parameters
        [
          Parameter.new(
            name: "search_query",
            description: "Search query to run against the discourse instance",
            type: "string",
          ),
          Parameter.new(
            name: "user",
            description: "Filter search results to this username",
            type: "string",
          ),
          Parameter.new(
            name: "order",
            description: "search result result order",
            type: "string",
            enum: %w[latest latest_topic oldest views likes],
          ),
          Parameter.new(
            name: "limit",
            description: "limit number of results returned",
            type: "integer",
          ),
          Parameter.new(
            name: "max_posts",
            description:
              "maximum number of posts on the topics (topics where lots of people posted)",
            type: "integer",
          ),
          Parameter.new(
            name: "tags",
            description:
              "list of tags to search for. Use + to join with OR, use , to join with AND",
            type: "string",
          ),
          Parameter.new(
            name: "category",
            description: "category name to filter to",
            type: "string",
          ),
          Parameter.new(
            name: "before",
            description: "only topics created before a specific date YYYY-MM-DD",
            type: "string",
          ),
          Parameter.new(
            name: "after",
            description: "only topics created after a specific date YYYY-MM-DD",
            type: "string",
          ),
          Parameter.new(
            name: "status",
            description: "search for topics in a particular state",
            type: "string",
            enum: %w[open closed archived noreplies single_user],
          ),
        ]
      end

      def custom_system_message
        "You were trained on OLD data, lean on search to get up to date information about this forum"
      end
    end

    def result_name
      "results"
    end

    def description_args
      {
        count: @last_num_results || 0,
        query: @last_query || "",
        url: "#{Discourse.base_path}/search?q=#{CGI.escape(@last_query || "")}",
      }
    end

    def process(search_string)
      parsed = JSON.parse(search_string)

      limit = nil

      search_string =
        parsed
          .map do |key, value|
            if key == "search_query"
              value
            elsif key == "limit"
              limit = value.to_i
              nil
            else
              "#{key}:#{value}"
            end
          end
          .compact
          .join(" ")

      @last_query = search_string
      results =
        Search.execute(
          search_string.to_s + " status:public",
          search_type: :full_page,
          guardian: Guardian.new(),
        )

      # let's be frugal with tokens, 50 results is too much and stuff gets cut off
      limit ||= 20
      limit = 20 if limit > 20

      posts = results&.posts || []
      posts = posts[0..limit - 1]

      @last_num_results = posts.length

      if posts.blank?
        []
      else
        format_results(posts) do |post|
          {
            title: post.topic.title,
            url: Discourse.base_path + post.url,
            excerpt: post.excerpt,
            created: post.created_at,
          }
        end
      end
    end
  end
end
