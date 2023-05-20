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
      "results"
    end

    def description_args
      {
        count: @last_num_results || 0,
        query: @last_query || "",
        url: "https://google.com/search?q=#{CGI.escape(@last_query || "")}",
      }
    end

    def process(search_string)
      @last_query = search_string
      api_key = SiteSetting.ai_google_custom_search_api_key
      cx = SiteSetting.ai_google_custom_search_cx
      query = CGI.escape(search_string)
      uri =
        URI("https://www.googleapis.com/customsearch/v1?key=#{api_key}&cx=#{cx}&q=#{query}&num=10")
      body = Net::HTTP.get(uri)

      parse_search_json(body).to_s
    end

    def parse_search_json(json_data)
      parsed = JSON.parse(json_data)
      results = parsed["items"]

      @last_num_results = parsed.dig("searchInformation", "totalResults").to_i

      formatted_results = []

      results.each do |result|
        formatted_result = {
          title: result["title"],
          link: result["link"],
          snippet: result["snippet"],
          displayLink: result["displayLink"],
          formattedUrl: result["formattedUrl"],
        }
        formatted_results << formatted_result
      end

      formatted_results
    end
  end
end
