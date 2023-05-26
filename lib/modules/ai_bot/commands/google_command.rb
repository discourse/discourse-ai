#frozen_string_literal: true

module DiscourseAi::AiBot::Commands
  class GoogleCommand < Command
    class << self
      def name
        "google"
      end

      def desc
        "!google SEARCH_QUERY - will search using Google (supports all Google search operators)"
      end
    end

    def result_name
      "Google Results"
    end

    def description_args
      {
        count: @last_num_results || 0,
        query: @last_query || "",
        url: "https://google.com/search?q=#{CGI.escape(@last_query || "")}",
      }
    end

    def process
      @last_query = @args
      api_key = SiteSetting.ai_google_custom_search_api_key
      cx = SiteSetting.ai_google_custom_search_cx
      query = CGI.escape(@args)
      uri =
        URI("https://www.googleapis.com/customsearch/v1?key=#{api_key}&cx=#{cx}&q=#{query}&num=10")
      body = Net::HTTP.get(uri)

      parse_search_json(body).to_s
    end

    def parse_search_json(json_data)
      parsed = JSON.parse(json_data)
      results = parsed["items"]

      @last_num_results = parsed.dig("searchInformation", "totalResults").to_i

      format_results(results) do |result|
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
