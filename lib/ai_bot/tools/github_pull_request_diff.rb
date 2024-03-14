# frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Tools
      class GithubPullRequestDiff < Tool
        LARGE_OBJECT_THRESHOLD = 30_000

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
          @url = "https://github.com/#{repo}/pull/#{pull_id}"

          response =
            send_http_request(
              api_url,
              headers: {
                "Accept" => "application/vnd.github.v3.diff",
              },
              authenticate_github: true,
            )

          if response.code == "200"
            diff = response.body
            diff = sort_and_shorten_diff(diff)
            diff = truncate(diff, max_length: 20_000, percent_length: 0.3, llm: llm)
            { diff: diff }
          else
            { error: "Failed to retrieve the diff. Status code: #{response.code}" }
          end
        end

        def description_args
          { repo: repo, pull_id: pull_id, url: url }
        end

        private

        def sort_and_shorten_diff(diff, threshold: LARGE_OBJECT_THRESHOLD)
          # This regex matches the start of a new file in the diff,
          # capturing the file paths for later use.
          file_start_regex = /^diff --git.*/

          prev_start = 0
          prev_match = nil

          split = []

          diff.scan(file_start_regex) do |match|
            match_start = $~.offset(0)[0] # Get the start position of this match

            if prev_start != 0
              full_diff = diff[prev_start...match_start]

              split << [prev_match, full_diff]
            end

            prev_match = match
            prev_start = match_start
          end

          split << [prev_match, diff[prev_start..-1]] if prev_match

          split.sort! { |x, y| x[1].length <=> y[1].length }

          split
            .map do |x, y|
              if y.length < threshold
                y
              else
                "#{x}\nRedacted, Larger than #{threshold} chars"
              end
            end
            .join("\n")
        end
      end
    end
  end
end
