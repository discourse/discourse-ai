# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class HuggingFace < Base
        def self.can_contact?(model_provider)
          model_provider == "hugging_face"
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
          { model: llm_model.name, temperature: 0.7 }
        end

        def provider_id
          AiApiAuditLog::Provider::HuggingFaceTextGeneration
        end

        private

        def model_uri
          URI(llm_model.url)
        end

        def prepare_payload(prompt, model_params, _dialect)
          default_options
            .merge(model_params)
            .merge(messages: prompt)
            .tap do |payload|
              if !payload[:max_tokens]
                token_limit = llm_model.max_prompt_tokens

                payload[:max_tokens] = token_limit - prompt_size(prompt)
              end

              payload[:stream] = true if @streaming_mode
            end
        end

        def prepare_request(payload)
          api_key = llm_model.api_key

          headers =
            { "Content-Type" => "application/json" }.tap do |h|
              h["Authorization"] = "Bearer #{api_key}" if api_key.present?
            end

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def extract_completion_from(response_raw)
          parsed = JSON.parse(response_raw, symbolize_names: true).dig(:choices, 0)
          # half a line sent here
          return if !parsed

          response_h = @streaming_mode ? parsed.dig(:delta) : parsed.dig(:message)

          response_h.dig(:content)
        end

        def partials_from(decoded_chunk)
          decoded_chunk
            .split("\n")
            .map do |line|
              data = line.split("data:", 2)[1]
              data&.squish == "[DONE]" ? nil : data
            end
            .compact
        end
      end
    end
  end
end
