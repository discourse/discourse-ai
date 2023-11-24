# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class OpenAiImageGenerator
      TIMEOUT = 60

      def self.perform!(prompt, model: "dall-e-3", size: "1024x1024", api_key: nil)
        api_key ||= SiteSetting.ai_openai_api_key

        url = URI("https://api.openai.com/v1/images/generations")
        headers = { "Content-Type" => "application/json", "Authorization" => "Bearer #{api_key}" }

        payload = { model: model, prompt: prompt, n: 1, size: size, response_format: "b64_json" }

        Net::HTTP.start(
          url.host,
          url.port,
          use_ssl: url.scheme == "https",
          read_timeout: TIMEOUT,
          open_timeout: TIMEOUT,
          write_timeout: TIMEOUT,
        ) do |http|
          request = Net::HTTP::Post.new(url, headers)
          request.body = payload.to_json

          json = nil
          http.request(request) do |response|
            if response.code.to_i != 200
              raise "OpenAI API returned #{response.code} #{response.body}"
            else
              json = JSON.parse(response.body, symbolize_names: true)
            end
          end
          json
        end
      end
    end
  end
end
