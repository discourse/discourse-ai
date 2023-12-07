# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class HuggingFace < Base
        def self.can_contact?(model_name)
          %w[StableBeluga2 Upstage-Llama-2-*-instruct-v2 Llama2-*-chat-hf Llama2-chat-hf].include?(
            model_name,
          )
        end

        def default_options
          { parameters: { repetition_penalty: 1.1, temperature: 0.7 } }
        end

        def provider_id
          AiApiAuditLog::Provider::HuggingFaceTextGeneration
        end

        private

        def model_uri
          URI(SiteSetting.ai_hugging_face_api_url)
        end

        def prepare_payload(prompt, model_params)
          default_options
            .merge(inputs: prompt)
            .tap do |payload|
              payload[:parameters].merge!(model_params)

              token_limit = SiteSetting.ai_hugging_face_token_limit || 4_000

              payload[:parameters][:max_new_tokens] = token_limit - prompt_size(prompt)
              payload[:parameters][:return_full_text] = false

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
          parsed = JSON.parse(response_raw, symbolize_names: true)

          if @streaming_mode
            # Last chunk contains full response, which we already yielded.
            return if parsed.dig(:token, :special)

            parsed.dig(:token, :text).to_s
          else
            parsed[0][:generated_text].to_s
          end
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
