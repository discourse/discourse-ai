# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Cohere < Base
        class << self
          def can_contact?(endpoint_name, model_name)
            return false unless endpoint_name == "cohere"

            %w[command-light command command-r command-r-plus].include?(model_name)
          end

          def dependant_setting_names
            %w[ai_cohere_api_key]
          end

          def correctly_configured?(model_name)
            SiteSetting.ai_cohere_api_key.present?
          end

          def endpoint_name(model_name)
            "Cohere - #{model_name}"
          end
        end

        def normalize_model_params(model_params)
          model_params = model_params.dup
          model_params[:p] = model_params.delete(:top_p) if model_params[:top_p]
          model_params
        end

        def default_options(dialect)
          options = { model: "command-r-plus" }

          options[:stop_sequences] = ["</function_calls>"] if dialect.prompt.has_tools?
          options
        end

        def provider_id
          AiApiAuditLog::Provider::Cohere
        end

        private

        def model_uri
          URI("https://api.cohere.ai/v1/chat")
        end

        def prepare_payload(prompt, model_params, dialect)
          payload = default_options(dialect).merge(model_params).merge(prompt)

          payload[:stream] = true if @streaming_mode

          payload
        end

        def prepare_request(payload)
          headers = {
            "Content-Type" => "application/json",
            "Authorization" => "Bearer #{SiteSetting.ai_cohere_api_key}",
          }

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def extract_completion_from(response_raw)
          parsed = JSON.parse(response_raw, symbolize_names: true)

          if @streaming_mode
            if parsed[:event_type] == "text-generation"
              parsed[:text]
            else
              if parsed[:event_type] == "stream-end"
                @input_tokens = parsed.dig(:response, :meta, :billed_units, :input_tokens)
                @output_tokens = parsed.dig(:response, :meta, :billed_units, :output_tokens)
              end
              nil
            end
          else
            @input_tokens = parsed.dig(:meta, :billed_units, :input_tokens)
            @output_tokens = parsed.dig(:meta, :billed_units, :output_tokens)
            parsed[:text].to_s
          end
        end

        def final_log_update(log)
          log.request_tokens = @input_tokens if @input_tokens
          log.response_tokens = @output_tokens if @output_tokens
        end

        def partials_from(decoded_chunk)
          decoded_chunk.split("\n").compact
        end

        def extract_prompt_for_tokenizer(prompt)
          text = +""
          if prompt[:chat_history]
            text << prompt[:chat_history]
              .map { |message| message[:content] || message["content"] || "" }
              .join("\n")
          end

          text << prompt[:message] if prompt[:message]
          text << prompt[:preamble] if prompt[:preamble]

          text
        end
      end
    end
  end
end
