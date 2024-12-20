# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class CloudflareWorkersAi
      def initialize(account_id, api_token, model, referer = Discourse.base_url)
        @account_id = account_id
        @api_token = api_token
        @model = model
        @referer = referer
      end

      def self.instance(model)
        new(
          SiteSetting.ai_cloudflare_workers_account_id,
          SiteSetting.ai_cloudflare_workers_api_token,
          model,
        )
      end

      attr_reader :account_id, :api_token, :model, :referer

      def perform!(content)
        headers = {
          "Referer" => Discourse.base_url,
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{api_token}",
        }

        payload = { text: [content] }

        endpoint = "https://api.cloudflare.com/client/v4/accounts/#{account_id}/ai/run/@cf/#{model}"

        conn = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
        response = conn.post(endpoint, payload.to_json, headers)

        case response.status
        when 200
          JSON.parse(response.body, symbolize_names: true).dig(:result, :data).first
        when 429
          # TODO add a AdminDashboard Problem?
        else
          Rails.logger.warn(
            "Cloudflare Workers AI Embeddings failed with status: #{response.status} body: #{response.body}",
          )
          raise Net::HTTPBadResponse
        end
      end
    end
  end
end
