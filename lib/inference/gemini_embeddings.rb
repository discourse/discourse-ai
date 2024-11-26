# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class GeminiEmbeddings
      def initialize(api_key, referer = Discourse.base_url)
        @api_key = api_key
        @referer = referer
      end

      attr_reader :api_key, :referer

      def perform!(content)
        headers = { "Referer" => referer, "Content-Type" => "application/json" }
        url =
          "https://generativelanguage.googleapis.com/v1beta/models/embedding-001:embedContent\?key\=#{api_key}"
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
