# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Vllm < Base
        def self.can_contact?(model_name)
          %w[mistralai/Mixtral-8x7B-Instruct-v0.1 mistralai/Mistral-7B-Instruct-v0.2].include?(model_name)
        end

        def default_options
          { max_tokens_to_sample: 2000, model: model }
        end

        def provider_id
          AiApiAuditLog::Provider::Vllm
        end

        private

        def model_uri
          service = DiscourseAi::Utils::DnsSrv.lookup(SiteSetting.ai_vllm_endpoint_srv)
          api_endpoint = "https://#{service.target}:#{service.port}/v1/completions"
          @uri ||= URI(api_endpoint)
        end

        def prepare_payload(prompt, model_params, _dialect)
          default_options
            .merge(model_params)
            .merge(prompt: prompt)
            .tap { |payload| payload[:stream] = true if @streaming_mode }
        end

        def prepare_request(payload)
          headers = { "Referer" => Discourse.base_url, "Content-Type" => "application/json" }

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def extract_completion_from(response_raw)
          pp response_raw
          parsed = JSON.parse(response_raw, symbolize_names: true).dig(:choices, 0)

          # half a line sent here
          return if !parsed

          parsed.dig(:text)
        end

        def partials_from(decoded_chunk)
          decoded_chunk
            .split("\n")
            .map do |line|
              data = line.split("data: ", 2)[1]
              data == "[DONE]" ? nil : data
            end
            .compact
        end
      end
    end
  end
end
