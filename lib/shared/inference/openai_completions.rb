# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class OpenAiCompletions
      def self.perform!(messages, model = "gpt-3.5-turbo")
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

        raise Net::HTTPBadResponse unless response.status == 200

        JSON.parse(response.body, symbolize_names: true)
      end
    end
  end
end
