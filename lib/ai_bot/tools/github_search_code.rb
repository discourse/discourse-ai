# frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Tools
      class GithubSearchCode < Tool
        def self.signature
          {
            name: name,
            description: "Searches for code in a GitHub repository",
            parameters: [
              {
                name: "repo",
                description: "The repository name in the format 'owner/repo'",
                type: "string",
                required: true,
              },
              {
                name: "query",
                description: "The search query (e.g., a function name, variable, or code snippet)",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "github_search_code"
        end

        def repo
          parameters[:repo]
        end

        def query
          parameters[:query]
        end

        def description_args
          { repo: repo, query: query }
        end

        def invoke(_bot_user, llm)
          api_url = "https://api.github.com/search/code?q=#{query}+repo:#{repo}"

          response =
            send_http_request(
              api_url,
              headers: {
                "Accept" => "application/vnd.github.v3.text-match+json",
              },
              authenticate_github: true,
            )

          if response.code == "200"
            search_data = JSON.parse(response.body)
            results =
              search_data["items"]
                .map { |item| "#{item["name"]}:\n#{item["text_matches"][0]["fragment"]}" }
                .join("\n---\n")

            results = truncate(results, max_length: 20_000, percent_length: 0.3, llm: llm)
            { search_results: results }
          else
            { error: "Failed to perform code search. Status code: #{response.code}" }
          end
        end
      end
    end
  end
end
