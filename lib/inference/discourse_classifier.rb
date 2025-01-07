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

      attr_reader :endpoint, :api_key, :model, :referer

      def perform!(content)
        headers = { "Referer" => referer, "Content-Type" => "application/json" }
        headers["X-API-KEY"] = api_key if api_key.present?

        conn = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
        response = conn.post(endpoint, { model: model, content: content }.to_json, headers)

        if ![200, 415].include?(response.status)
          raise raise Net::HTTPBadResponse.new(response.body.to_s)
        end

        JSON.parse(response.body, symbolize_names: true)
      end
    end
  end
end
