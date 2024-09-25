# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Ollama < Base
        def self.can_contact?(model_provider)
          model_provider == "ollama"
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
          AiApiAuditLog::Provider::Ollama
        end

        def use_ssl?
          false
        end

        private

        def model_uri
          URI(llm_model.url)
        end

        def prepare_payload(prompt, model_params, _dialect)
          default_options
            .merge(model_params)
            .merge(messages: prompt)
            .tap { |payload| payload[:stream] = false if !@streaming_mode }
        end

        def prepare_request(payload)
          headers = { "Content-Type" => "application/json" }

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def partials_from(decoded_chunk)
          decoded_chunk
            .split("\n")
            .compact
        end

        def extract_completion_from(response_raw)
          parsed = JSON.parse(response_raw, symbolize_names: true)
          return if !parsed

          parsed.dig(:message, :content)
        end
      end
    end
  end
end
