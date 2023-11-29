# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class HuggingFaceTextEmbeddings
      def self.perform!(content)
        headers = { "Referer" => Discourse.base_url, "Content-Type" => "application/json" }
        body = { inputs: content }.to_json

        api_endpoint = SiteSetting.ai_hugging_face_tei_endpoint

        response = Faraday.post(api_endpoint, body, headers)

        raise Net::HTTPBadResponse if ![200].include?(response.status)

        JSON.parse(response.body, symbolize_names: true)
      end
    end
  end
end
