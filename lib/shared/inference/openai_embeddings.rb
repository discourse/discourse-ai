# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class OpenAiEmbeddings
      def self.perform!(content, model = nil)
        headers = {
          "Authorization" => "Bearer #{SiteSetting.ai_openai_api_key}",
          "Content-Type" => "application/json",
        }

        model ||= "text-embedding-ada-002"

        response =
          Faraday.post(
            "https://api.openai.com/v1/embeddings",
            { model: model, input: content }.to_json,
            headers,
          )

        raise Net::HTTPBadResponse unless response.status == 200

        JSON.parse(response.body, symbolize_names: true)
      end
    end
  end
end
