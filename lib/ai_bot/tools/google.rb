# frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Tools
      class Google < Tool
        def self.signature
          {
            name: name,
            description:
              "Will search using Google - global internet search (supports all Google search operators)",
            parameters: [
              { name: "query", description: "The search query", type: "string", required: true },
            ],
          }
        end

        def self.custom_system_message
          "You were trained on OLD data, lean on search to get up to date information from the web"
        end

        def self.name
          "google"
        end

        def query
          parameters[:query].to_s.strip
        end

        def invoke(bot_user, llm)
          yield(query)

          api_key = SiteSetting.ai_google_custom_search_api_key
          cx = SiteSetting.ai_google_custom_search_cx
          escaped_query = CGI.escape(query)
          uri =
            URI(
              "https://www.googleapis.com/customsearch/v1?key=#{api_key}&cx=#{cx}&q=#{escaped_query}&num=10",
            )
          body = Net::HTTP.get(uri)

          parse_search_json(body, escaped_query, llm)
        end

        attr_reader :results_count

        protected

        def description_args
          {
            count: results_count || 0,
            query: query,
            url: "https://google.com/search?q=#{CGI.escape(query)}",
          }
        end

        private

        def minimize_field(result, field, llm, max_tokens: 100)
          data = result[field]
          return "" if data.blank?

          llm.tokenizer.truncate(data, max_tokens).squish
        end

        def parse_search_json(json_data, escaped_query, llm)
          parsed = JSON.parse(json_data)
          results = parsed["items"]

          @results_count = parsed.dig("searchInformation", "totalResults").to_i

          format_results(results, args: escaped_query) do |result|
            {
              title: minimize_field(result, "title", llm),
              link: minimize_field(result, "link", llm),
              snippet: minimize_field(result, "snippet", llm, max_tokens: 120),
              displayLink: minimize_field(result, "displayLink", llm),
              formattedUrl: minimize_field(result, "formattedUrl", llm),
            }
          end
        end
      end
    end
  end
end
