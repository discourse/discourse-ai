# frozen_string_literal: true

module ::DiscourseAI
  class InferenceManager
    def self.perform!(endpoint, model, content, api_key)
      headers = { "Referer" => Discourse.base_url, "Content-Type" => "application/json" }

      headers["X-API-KEY"] = api_key if api_key.present?

      response = Faraday.post(endpoint, { model: model, content: content }.to_json, headers)

      raise Net::HTTPBadResponse unless response.status == 200

      JSON.parse(response.body)
    end
  end
end
