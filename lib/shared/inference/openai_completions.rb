# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class OpenAiCompletions
      def self.perform!(content, model = "gpt-3.5-turbo")
        headers = {
          "Authorization" => "Bearer #{SiteSetting.ai_openai_api_key}",
          "Content-Type" => "application/json",
        }

        connection_opts = { request: { write_timeout: 10, read_timeout: 10, open_timeout: 10 } }

        response =
          Faraday.new(nil, connection_opts).post(
            "https://api.openai.com/v1/chat/completions",
            { model: model, messages: content }.to_json,
            headers,
          )

        raise Net::HTTPBadResponse unless response.status == 200

        JSON.parse(response.body, symbolize_names: true)
      end
    end
  end
end
