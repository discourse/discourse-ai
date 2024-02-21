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

        raise Net::HTTPBadResponse if ![200].include?(response.status)

        JSON.parse(response.body, symbolize_names: true)
      end
    end
  end
end
