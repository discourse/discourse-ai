# frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Tools
      class GithubPullRequestDiff < Tool
        def self.signature
          {
            name: name,
            description: "Retrieves the diff for a GitHub pull request",
            parameters: [
              {
                name: "repo",
                description: "The repository name in the format 'owner/repo'",
                type: "string",
                required: true,
              },
              {
                name: "pull_id",
                description: "The ID of the pull request",
                type: "integer",
                required: true,
              },
            ],
          }
        end

        def self.name
          "github_pull_request_diff"
        end

        def repo
          parameters[:repo]
        end

        def pull_id
          parameters[:pull_id]
        end

        def url
          @url
        end

        def invoke(_bot_user, llm)
          api_url = "https://api.github.com/repos/#{repo}/pulls/#{pull_id}"
          @url = "https://github.com/repos/#{repo}/pulls/#{pull_id}"

          response = send_request(api_url)

          if response.code == "200"
            diff = response.body
            diff = truncate(diff, max_length: 20_000, percent_length: 0.3, llm: llm)
            { diff: diff }
          else
            { error: "Failed to retrieve the diff. Status code: #{response.code}" }
          end
        end

        private

        def send_request(api_url)
          uri = URI(api_url)
          request = Net::HTTP::Get.new(uri)
          request["Accept"] = "application/vnd.github.v3.diff"
          request["User-Agent"] = "Ruby"

          Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
        end

        def description_args
          { repo: repo, pull_id: pull_id, url: url }
        end
      end
    end
  end
end
