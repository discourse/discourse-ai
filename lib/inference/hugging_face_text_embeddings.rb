# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class HuggingFaceTextEmbeddings
      def initialize(endpoint, key, referer = Discourse.base_url)
        @endpoint = endpoint
        @key = key
        @referer = referer
      end

      attr_reader :endpoint, :key, :referer

      class << self
        def instance
          endpoint =
            if SiteSetting.ai_hugging_face_tei_endpoint_srv.present?
              service =
                DiscourseAi::Utils::DnsSrv.lookup(SiteSetting.ai_hugging_face_tei_endpoint_srv)
              "https://#{service.target}:#{service.port}"
            else
              SiteSetting.ai_hugging_face_tei_endpoint
            end

          new(endpoint, SiteSetting.ai_hugging_face_tei_api_key)
        end

        def configured?
          SiteSetting.ai_hugging_face_tei_endpoint.present? ||
            SiteSetting.ai_hugging_face_tei_endpoint_srv.present?
        end

        def reranker_configured?
          SiteSetting.ai_hugging_face_tei_reranker_endpoint.present? ||
            SiteSetting.ai_hugging_face_tei_reranker_endpoint_srv.present?
        end

        def rerank(content, candidates)
          headers = { "Referer" => Discourse.base_url, "Content-Type" => "application/json" }
          body = { query: content, texts: candidates, truncate: true }.to_json

          if SiteSetting.ai_hugging_face_tei_reranker_endpoint_srv.present?
            service =
              DiscourseAi::Utils::DnsSrv.lookup(
                SiteSetting.ai_hugging_face_tei_reranker_endpoint_srv,
              )
            api_endpoint = "https://#{service.target}:#{service.port}"
          else
            api_endpoint = SiteSetting.ai_hugging_face_tei_reranker_endpoint
          end

          if SiteSetting.ai_hugging_face_tei_reranker_api_key.present?
            headers["X-API-KEY"] = SiteSetting.ai_hugging_face_tei_reranker_api_key
            headers["Authorization"] = "Bearer #{SiteSetting.ai_hugging_face_tei_reranker_api_key}"
          end

          conn = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
          response = conn.post("#{api_endpoint}/rerank", body, headers)

          if response.status != 200
            raise Net::HTTPBadResponse.new("Status: #{response.status}\n\n#{response.body}")
          end

          JSON.parse(response.body, symbolize_names: true)
        end

        def classify(content, model_config)
          headers = { "Referer" => Discourse.base_url, "Content-Type" => "application/json" }
          headers["X-API-KEY"] = model_config.api_key
          headers["Authorization"] = "Bearer #{model_config.api_key}"

          body = { inputs: content, truncate: true }.to_json

          api_endpoint = model_config.endpoint
          if api_endpoint.present? && api_endpoint.start_with?("srv://")
            service = DiscourseAi::Utils::DnsSrv.lookup(api_endpoint.delete_prefix("srv://"))
            api_endpoint = "https://#{service.target}:#{service.port}"
          end

          conn = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
          response = conn.post(api_endpoint, body, headers)

          if response.status != 200
            raise Net::HTTPBadResponse.new("Status: #{response.status}\n\n#{response.body}")
          end

          JSON.parse(response.body, symbolize_names: true)
        end
      end

      def perform!(content)
        headers = { "Referer" => referer, "Content-Type" => "application/json" }
        body = { inputs: content, truncate: true }.to_json

        if key.present?
          headers["X-API-KEY"] = key
          headers["Authorization"] = "Bearer #{key}"
        end

        conn = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
        response = conn.post(endpoint, body, headers)

        raise Net::HTTPBadResponse if ![200].include?(response.status)

        JSON.parse(response.body, symbolize_names: true).first
      end
    end
  end
end
