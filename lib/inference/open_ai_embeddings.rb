# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class OpenAiEmbeddings
      def initialize(endpoint, api_key, model, dimensions)
        @endpoint = endpoint
        @api_key = api_key
        @model = model
        @dimensions = dimensions
      end

      attr_reader :endpoint, :api_key, :model, :dimensions

      def self.instance(model:, dimensions: nil)
        new(SiteSetting.ai_openai_embeddings_url, SiteSetting.ai_openai_api_key, model, dimensions)
      end

      def perform!(content)
        headers = { "Content-Type" => "application/json" }

        if endpoint.include?("azure")
          headers["api-key"] = api_key
        else
          headers["Authorization"] = "Bearer #{api_key}"
        end

        payload = { model: model, input: content }
        payload[:dimensions] = dimensions if dimensions.present?

        conn = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
        response = conn.post(SiteSetting.ai_openai_embeddings_url, payload.to_json, headers)

        case response.status
        when 200
          JSON.parse(response.body, symbolize_names: true).dig(:data, 0, :embedding)
        when 429
          # TODO add a AdminDashboard Problem?
        else
          Rails.logger.warn(
            "OpenAI Embeddings failed with status: #{response.status} body: #{response.body}",
          )
          raise Net::HTTPBadResponse
        end
      end
    end
  end
end
