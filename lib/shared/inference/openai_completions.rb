# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class OpenAiCompletions
      CompletionFailed = Class.new(StandardError)

      def self.perform!(messages, model = SiteSetting.ai_helper_model)
        headers = {
          "Authorization" => "Bearer #{SiteSetting.ai_openai_api_key}",
          "Content-Type" => "application/json",
        }

        connection_opts = { request: { write_timeout: 60, read_timeout: 60, open_timeout: 60 } }

        response =
          Faraday.new(nil, connection_opts).post(
            "https://api.openai.com/v1/chat/completions",
            { model: model, messages: messages }.to_json,
            headers,
          )

        if response.status != 200
          Rails.logger.error(
            "OpenAiCompletions: status: #{response.status} - body: #{response.body}",
          )
          raise CompletionFailed
        end

        JSON.parse(response.body, symbolize_names: true)
      end
    end
  end
end
