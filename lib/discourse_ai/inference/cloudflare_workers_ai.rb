# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class CloudflareWorkersAi
      def self.perform!(model, content)
        headers = { "Referer" => Discourse.base_url, "Content-Type" => "application/json" }

        account_id = SiteSetting.ai_cloudflare_workers_account_id
        token = SiteSetting.ai_cloudflare_workers_api_token

        base_url = "https://api.cloudflare.com/client/v4/accounts/#{account_id}/ai/run/@cf/"
        headers["Authorization"] = "Bearer #{token}"

        endpoint = "#{base_url}#{model}"

        conn = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
        response = conn.post(endpoint, content.to_json, headers)

        raise Net::HTTPBadResponse if ![200].include?(response.status)

        JSON.parse(response.body, symbolize_names: true)
      end
    end
  end
end
