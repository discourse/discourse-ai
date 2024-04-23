# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class HuggingFace < Base
        class << self
          def can_contact?(endpoint_name, model_name)
            return false unless endpoint_name == "hugging_face"

            %w[mistralai/Mixtral-8x7B-Instruct-v0.1 mistralai/Mistral-7B-Instruct-v0.2].include?(
              model_name,
            )
          end

          def dependant_setting_names
            %w[ai_hugging_face_api_url]
          end

          def correctly_configured?(_model_name)
            SiteSetting.ai_hugging_face_api_url.present?
          end

          def endpoint_name(model_name)
            "Hugging Face - #{model_name}"
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
          { model: model, temperature: 0.7 }
        end

        def provider_id
          AiApiAuditLog::Provider::HuggingFaceTextGeneration
        end

        private

        def model_uri
          URI(SiteSetting.ai_hugging_face_api_url)
        end

        def prepare_payload(prompt, model_params, _dialect)
          default_options
            .merge(model_params)
            .merge(messages: prompt)
            .tap do |payload|
              if !payload[:max_tokens]
                token_limit = SiteSetting.ai_hugging_face_token_limit || 4_000

                payload[:max_tokens] = token_limit - prompt_size(prompt)
              end

              payload[:stream] = true if @streaming_mode
            end
        end

        def prepare_request(payload)
          headers =
            { "Content-Type" => "application/json" }.tap do |h|
              if SiteSetting.ai_hugging_face_api_key.present?
                h["Authorization"] = "Bearer #{SiteSetting.ai_hugging_face_api_key}"
              end
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
