#frozen_string_literal: true

module DiscourseAi::AiBot::Commands
  class GoogleCommand < Command
    class << self
      def name
        "google"
      end

      def desc
        "Will search using Google - global internet search (supports all Google search operators)"
      end

      def parameters
        [
          Parameter.new(
            name: "query",
            description: "The search query",
            type: "string",
            required: true,
          ),
        ]
      end

      def custom_system_message
        "You were trained on OLD data, lean on search to get up to date information from the web"
      end
    end

    def result_name
      "results"
    end

    def description_args
      {
        count: @last_num_results || 0,
        query: @last_query || "",
        url: "https://google.com/search?q=#{CGI.escape(@last_query || "")}",
      }
    end

    def process(query:)
      @last_query = query
      api_key = SiteSetting.ai_google_custom_search_api_key
      cx = SiteSetting.ai_google_custom_search_cx
      query = CGI.escape(query)
      uri =
        URI("https://www.googleapis.com/customsearch/v1?key=#{api_key}&cx=#{cx}&q=#{query}&num=10")
      body = Net::HTTP.get(uri)

      parse_search_json(body)
    end

    def parse_search_json(json_data)
      parsed = JSON.parse(json_data)
      results = parsed["items"]

      @last_num_results = parsed.dig("searchInformation", "totalResults").to_i

      format_results(results, args: json_data) do |result|
        {
          title: result["title"],
          link: result["link"],
          snippet: result["snippet"],
          displayLink: result["displayLink"],
          formattedUrl: result["formattedUrl"],
        }
      end
    end
  end
end
