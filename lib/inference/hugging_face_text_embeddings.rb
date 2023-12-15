# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class HuggingFaceTextEmbeddings
      def self.perform!(content)
        headers = { "Referer" => Discourse.base_url, "Content-Type" => "application/json" }
        body = { inputs: content, truncate: true }.to_json

        if SiteSetting.ai_hugging_face_tei_endpoint_srv.present?
          service = DiscourseAi::Helper::DnsSrvHelper.dns_srv_lookup(SiteSetting.ai_hugging_face_tei_endpoint_srv)
          api_endpoint = "https://#{service.target}:#{service.port}"
        else
          api_endpoint = SiteSetting.ai_hugging_face_tei_endpoint
        end

        response = Faraday.post(api_endpoint, body, headers)

        raise Net::HTTPBadResponse if ![200].include?(response.status)

        JSON.parse(response.body, symbolize_names: true)
      end

      def self.configured?
        SiteSetting.ai_hugging_face_tei_endpoint.present? || SiteSetting.ai_hugging_face_tei_endpoint_srv.present?
      end
    end
  end
end
