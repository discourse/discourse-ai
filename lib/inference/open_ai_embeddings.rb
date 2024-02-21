# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class OpenAiEmbeddings
      def self.perform!(content, model:, dimensions: nil)
        headers = { "Content-Type" => "application/json" }

        if SiteSetting.ai_openai_embeddings_url.include?("azure")
          headers["api-key"] = SiteSetting.ai_openai_api_key
        else
          headers["Authorization"] = "Bearer #{SiteSetting.ai_openai_api_key}"
        end

        payload = { model: model, input: content }
        payload[:dimensions] = dimensions if dimensions.present?

        conn = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
        response = conn.post(SiteSetting.ai_openai_embeddings_url, payload.to_json, headers)

        case response.status
        when 200
          JSON.parse(response.body, symbolize_names: true)
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
