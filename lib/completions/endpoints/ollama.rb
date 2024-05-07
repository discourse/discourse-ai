# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Ollama < Base
        class << self
          def can_contact?(endpoint_name, model_name)
            endpoint_name == "ollama" && %w[mistral].include?(model_name)
          end

          def dependant_setting_names
            %w[ai_ollama_endpoint]
          end

          def correctly_configured?(_model_name)
            SiteSetting.ai_ollama_endpoint.present?
          end

          def endpoint_name(model_name)
            "Ollama - #{model_name}"
          end
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
          { max_tokens: 2000, model: model }
        end

        def provider_id
          AiApiAuditLog::Provider::Ollama
        end

        def use_ssl?
          false
        end

        private

        def model_uri
          URI("#{SiteSetting.ai_ollama_endpoint}/v1/chat/completions")
        end

        def prepare_payload(prompt, model_params, _dialect)
          default_options
            .merge(model_params)
            .merge(messages: prompt)
            .tap { |payload| payload[:stream] = true if @streaming_mode }
        end

        def prepare_request(payload)
          headers = { "Content-Type" => "application/json" }

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
