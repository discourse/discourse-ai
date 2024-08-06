# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class GeminiEmbeddings
      def self.perform!(content)
        headers = { "Referer" => Discourse.base_url, "Content-Type" => "application/json" }

        url =
          "https://generativelanguage.googleapis.com/v1beta/models/embedding-001:embedContent\?key\=#{SiteSetting.ai_gemini_api_key}"

        body = { content: { parts: [{ text: content }] } }

        conn = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
        response = conn.post(url, body.to_json, headers)

        case response.status
        when 200
          JSON.parse(response.body, symbolize_names: true)
        when 429
          # TODO add a AdminDashboard Problem?
        else
          Rails.logger.warn(
            "Google Gemini Embeddings failed with status: #{response.status} body: #{response.body}",
          )
          raise Net::HTTPBadResponse
        end
      end
    end
  end
end
