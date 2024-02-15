# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class Llava
      def self.perform!(content)
        headers = { "Referer" => Discourse.base_url, "Content-Type" => "application/json" }
        body = content.to_json

        if SiteSetting.ai_llava_endpoint_srv.present?
          service = DiscourseAi::Utils::DnsSrv.lookup(SiteSetting.ai_llava_endpoint_srv)
          api_endpoint = "https://#{service.target}:#{service.port}"
        else
          api_endpoint = SiteSetting.ai_llava_endpoint
        end

        headers["X-API-KEY"] = SiteSetting.ai_llava_api_key if SiteSetting.ai_llava_api_key.present?

        response = Faraday.post("#{api_endpoint}/predictions", body, headers)

        raise Net::HTTPBadResponse if ![200].include?(response.status)

        JSON.parse(response.body, symbolize_names: true)
      end

      def self.configured?
        SiteSetting.ai_llava_endpoint.present? || SiteSetting.ai_llava_endpoint_srv.present?
      end
    end
  end
end
