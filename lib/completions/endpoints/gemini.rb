# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Gemini < Base
        def self.can_contact?(model_name)
          %w[gemini-pro].include?(model_name)
        end

        def default_options
          {}
        end

        def provider_id
          AiApiAuditLog::Provider::Gemini
        end

        private

        def model_uri
          url =
            "https://generativelanguage.googleapis.com/v1beta/models/#{model}:#{@streaming_mode ? "streamGenerateContent" : "generateContent"}?key=#{SiteSetting.ai_gemini_api_key}"

          URI(url)
        end

        def prepare_payload(prompt, model_params)
          default_options.merge(model_params).merge(contents: prompt)
        end

        def prepare_request(payload)
          headers = { "Content-Type" => "application/json" }

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def extract_completion_from(response_raw)
          if @streaming_mode
            parsed = response_raw
          else
            parsed = JSON.parse(response_raw, symbolize_names: true)
          end

          completion = dig_text(parsed).to_s
        end

        def partials_from(decoded_chunk)
          JSON.parse(decoded_chunk, symbolize_names: true)
        end

        def extract_prompt_for_tokenizer(prompt)
          prompt.to_s
        end

        def dig_text(response)
          response.dig(:candidates, 0, :content, :parts, 0, :text)
        end
      end
    end
  end
end
