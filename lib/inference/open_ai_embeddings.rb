# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class OpenAiEmbeddings
      def self.perform!(content, model = nil)
        headers = { "Content-Type" => "application/json" }

        if SiteSetting.ai_openai_embeddings_url.include?("azure")
          headers["api-key"] = SiteSetting.ai_openai_api_key
        else
          headers["Authorization"] = "Bearer #{SiteSetting.ai_openai_api_key}"
        end

        model ||= "text-embedding-ada-002"

        response =
          Faraday.post(
            SiteSetting.ai_openai_embeddings_url,
            { model: model, input: content }.to_json,
            headers,
          )
        if response.status != 200
          Rails.logger.warn(
            "OpenAI Embeddings failed with status: #{response.status} body: #{response.body}",
          )
          raise Net::HTTPBadResponse
        end

        JSON.parse(response.body, symbolize_names: true)
      end
    end
  end
end
