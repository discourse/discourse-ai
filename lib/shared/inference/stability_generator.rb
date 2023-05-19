# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class StabilityGenerator
      def self.perform!(prompt)
        headers = {
          "Referer" => Discourse.base_url,
          "Content-Type" => "application/json",
          "Accept" => "application/json",
          "Authorization" => "Bearer #{SiteSetting.ai_stability_api_key}",
        }

        payload = {
          text_prompts: [{ text: prompt }],
          cfg_scale: 7,
          clip_guidance_preset: "FAST_BLUE",
          height: 512,
          width: 512,
          samples: 4,
          steps: 30,
        }

        base_url = SiteSetting.ai_stability_api_url
        engine = SiteSetting.ai_stability_engine
        endpoint = "v1/generation/#{engine}/text-to-image"

        response = Faraday.post("#{base_url}/#{endpoint}", payload.to_json, headers)

        raise Net::HTTPBadResponse if response.status != 200

        JSON.parse(response.body, symbolize_names: true)
      end
    end
  end
end
