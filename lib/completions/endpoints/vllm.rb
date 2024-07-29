# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Vllm < Base
        def self.can_contact?(model_provider)
          model_provider == "vllm"
        end

        def normalize_model_params(model_params)
          model_params = model_params.dup

          # max_tokens, temperature are already supported
          if model_params[:stop_sequences]
            model_params[:stop] = model_params.delete(:stop_sequences)
          end

          model_params
        end

        def default_options
          { max_tokens: 2000, model: llm_model.name }
        end

        def provider_id
          AiApiAuditLog::Provider::Vllm
        end

        private

        def model_uri
          if llm_model.url == LlmModel::RESERVED_VLLM_SRV_URL
            service = DiscourseAi::Utils::DnsSrv.lookup(SiteSetting.ai_vllm_endpoint_srv)
            api_endpoint = "https://#{service.target}:#{service.port}/v1/chat/completions"
          else
            api_endpoint = llm_model.url
          end

          @uri ||= URI(api_endpoint)
        end

        def prepare_payload(prompt, model_params, _dialect)
          default_options
            .merge(model_params)
            .merge(messages: prompt)
            .tap { |payload| payload[:stream] = true if @streaming_mode }
        end

        def prepare_request(payload)
          headers = { "Referer" => Discourse.base_url, "Content-Type" => "application/json" }

          api_key = llm_model&.api_key || SiteSetting.ai_vllm_api_key
          headers["X-API-KEY"] = api_key if api_key.present?

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
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

        def extract_completion_from(response_raw)
          parsed = JSON.parse(response_raw, symbolize_names: true).dig(:choices, 0)
          # half a line sent here
          return if !parsed

          response_h = @streaming_mode ? parsed.dig(:delta) : parsed.dig(:message)

          response_h.dig(:content)
        end
      end
    end
  end
end
