# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class OpenAiImageGenerator
      TIMEOUT = 60

      def self.perform!(prompt, model: "dall-e-3", size: "1024x1024", api_key: nil, api_url: nil)
        api_key ||= SiteSetting.ai_openai_api_key
        api_url ||= SiteSetting.ai_openai_dall_e_3_url

        uri = URI(api_url)

        headers = { "Content-Type" => "application/json", "quality" => "hd" }

        if uri.host.include?("azure")
          headers["api-key"] = api_key
        else
          headers["Authorization"] = "Bearer #{api_key}"
        end

        payload = { model: model, prompt: prompt, n: 1, size: size, response_format: "b64_json" }

        Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == "https",
          read_timeout: TIMEOUT,
          open_timeout: TIMEOUT,
          write_timeout: TIMEOUT,
        ) do |http|
          request = Net::HTTP::Post.new(uri, headers)
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
