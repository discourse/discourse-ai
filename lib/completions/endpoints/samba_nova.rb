# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class SambaNova < Base
        def self.can_contact?(model_provider)
          model_provider == "samba_nova"
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
          { model: llm_model.name }
        end

        def provider_id
          AiApiAuditLog::Provider::SambaNova
        end

        private

        def model_uri
          URI(llm_model.url)
        end

        def prepare_payload(prompt, model_params, dialect)
          payload = default_options.merge(model_params).merge(messages: prompt)

          payload[:stream] = true if @streaming_mode

          payload
        end

        def prepare_request(payload)
          headers = { "Content-Type" => "application/json" }
          api_key = llm_model.api_key

          headers["Authorization"] = "Bearer #{api_key}"

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def final_log_update(log)
          log.request_tokens = @prompt_tokens if @prompt_tokens
          log.response_tokens = @completion_tokens if @completion_tokens
        end

        def extract_completion_from(response_raw)
          json = JSON.parse(response_raw, symbolize_names: true)

          if @streaming_mode
            @prompt_tokens ||= json.dig(:usage, :prompt_tokens)
            @completion_tokens ||= json.dig(:usage, :completion_tokens)
          end

          parsed = json.dig(:choices, 0)
          return if !parsed

          @streaming_mode ? parsed.dig(:delta, :content) : parsed.dig(:message, :content)
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