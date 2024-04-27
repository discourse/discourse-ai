# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class HuggingFaceTextEmbeddings
      class << self
        def perform!(content)
          headers = { "Referer" => Discourse.base_url, "Content-Type" => "application/json" }
          body = { inputs: content, truncate: true }.to_json

          if SiteSetting.ai_hugging_face_tei_endpoint_srv.present?
            service =
              DiscourseAi::Utils::DnsSrv.lookup(SiteSetting.ai_hugging_face_tei_endpoint_srv)
            api_endpoint = "https://#{service.target}:#{service.port}"
          else
            api_endpoint = SiteSetting.ai_hugging_face_tei_endpoint
          end

          if SiteSetting.ai_hugging_face_tei_api_key.present?
            headers["Authorization"] = "Bearer #{SiteSetting.ai_hugging_face_tei_api_key}"
          end

          conn = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
          response = conn.post(api_endpoint, body, headers)

          raise Net::HTTPBadResponse if ![200].include?(response.status)

          JSON.parse(response.body, symbolize_names: true)
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
            headers["Authorization"] = "Bearer #{SiteSetting.ai_hugging_face_tei_reranker_api_key}"
          end

          conn = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
          response = conn.post("#{api_endpoint}/rerank", body, headers)

          if response.status != 200
            raise Net::HTTPBadResponse.new("Status: #{response.status}\n\n#{response.body}")
          end

          JSON.parse(response.body, symbolize_names: true)
        end

        def reranker_configured?
          SiteSetting.ai_hugging_face_tei_reranker_endpoint.present? ||
            SiteSetting.ai_hugging_face_tei_reranker_endpoint_srv.present?
        end

        def configured?
          SiteSetting.ai_hugging_face_tei_endpoint.present? ||
            SiteSetting.ai_hugging_face_tei_endpoint_srv.present?
        end
      end
    end
  end
end
