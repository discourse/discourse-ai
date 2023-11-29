# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class DiscourseClassifier
      def self.perform!(endpoint, model, content, api_key)
        headers = { "Referer" => Discourse.base_url, "Content-Type" => "application/json" }

        headers["X-API-KEY"] = api_key if api_key.present?

        response = Faraday.post(endpoint, { model: model, content: content }.to_json, headers)

        raise Net::HTTPBadResponse if ![200, 415].include?(response.status)

        JSON.parse(response.body, symbolize_names: true)
      end
    end
  end
end
