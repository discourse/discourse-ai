# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class AnthropicCompletions
      CompletionFailed = Class.new(StandardError)

      def self.perform!(prompt)
        headers = {
          "x-api-key" => SiteSetting.ai_anthropic_api_key,
          "Content-Type" => "application/json",
        }

        model = "claude-v1"

        connection_opts = { request: { write_timeout: 60, read_timeout: 60, open_timeout: 60 } }

        response =
          Faraday.new(nil, connection_opts).post(
            "https://api.anthropic.com/v1/complete",
            { model: model, prompt: prompt, max_tokens_to_sample: 300 }.to_json,
            headers,
          )

        if response.status != 200
          Rails.logger.error(
            "AnthropicCompletions: status: #{response.status} - body: #{response.body}",
          )
          raise CompletionFailed
        end

        JSON.parse(response.body, symbolize_names: true)
      end
    end
  end
end
