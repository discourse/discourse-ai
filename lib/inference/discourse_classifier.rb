# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class DiscourseClassifier
      def initialize(endpoint, api_key, model, referer = Discourse.base_url)
        @endpoint = endpoint
        @api_key = api_key
        @model = model
        @referer = referer
      end

      def self.instance(model)
        endpoint =
          if SiteSetting.ai_embeddings_discourse_service_api_endpoint_srv.present?
            service =
              DiscourseAi::Utils::DnsSrv.lookup(
                SiteSetting.ai_embeddings_discourse_service_api_endpoint_srv,
              )
            "https://#{service.target}:#{service.port}"
          else
            SiteSetting.ai_embeddings_discourse_service_api_endpoint
          end

        new(
          "#{endpoint}/api/v1/classify",
          SiteSetting.ai_embeddings_discourse_service_api_key,
          model,
        )
      end

      attr_reader :endpoint, :api_key, :model, :referer

      def perform!(content)
        headers = { "Referer" => referer, "Content-Type" => "application/json" }
        headers["X-API-KEY"] = api_key if api_key.present?

        conn = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
        response = conn.post(endpoint, { model: model, content: content }.to_json, headers)

        raise Net::HTTPBadResponse if ![200, 415].include?(response.status)

        JSON.parse(response.body, symbolize_names: true)
      end
    end
  end
end
