# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class StabilityGenerator
      def self.perform!(prompt, width: nil, height: nil)
        headers = {
          "Referer" => Discourse.base_url,
          "Content-Type" => "application/json",
          "Accept" => "application/json",
          "Authorization" => "Bearer #{SiteSetting.ai_stability_api_key}",
        }

        sdxl_allowed_dimentions = [
          [1024, 1024],
          [1152, 896],
          [1216, 832],
          [1344, 768],
          [1536, 640],
          [640, 1536],
          [768, 1344],
          [832, 1216],
          [896, 1152],
        ]

        if (!width && !height)
          if SiteSetting.ai_stability_engine.include? "xl"
            width, height = sdxl_allowed_dimentions[0]
          else
            width, height = [512, 512]
          end
        end

        payload = {
          text_prompts: [{ text: prompt }],
          cfg_scale: 7,
          clip_guidance_preset: "FAST_BLUE",
          height: width,
          width: height,
          samples: 4,
          steps: 30,
        }

        base_url = SiteSetting.ai_stability_api_url
        engine = SiteSetting.ai_stability_engine
        endpoint = "v1/generation/#{engine}/text-to-image"

        response = Faraday.post("#{base_url}/#{endpoint}", payload.to_json, headers)

        if response.status != 200
          Rails.logger.error(
            "AI stability generator failed with status #{response.status}: #{response.body}}",
          )
          raise Net::HTTPBadResponse
        end

        JSON.parse(response.body, symbolize_names: true)
      end
    end
  end
end
