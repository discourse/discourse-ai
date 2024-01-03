# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Anthropic < Base
        def self.can_contact?(model_name)
          %w[claude-instant-1 claude-2].include?(model_name)
        end

        def normalize_model_params(model_params)
          model_params = model_params.dup

          # temperature, stop_sequences are already supported
          #
          if model_params[:max_tokens]
            model_params[:max_tokens_to_sample] = model_params.delete(:max_tokens)
          end

          model_params
        end

        def default_options
          {
            model: model,
            max_tokens_to_sample: 3_000,
            stop_sequences: ["\n\nHuman:", "</function_calls>"],
          }
        end

        def provider_id
          AiApiAuditLog::Provider::Anthropic
        end

        private

        def model_uri
          @uri ||= URI("https://api.anthropic.com/v1/complete")
        end

        def prepare_payload(prompt, model_params, _dialect)
          default_options
            .merge(model_params)
            .merge(prompt: prompt)
            .tap { |payload| payload[:stream] = true if @streaming_mode }
        end

        def prepare_request(payload)
          headers = {
            "anthropic-version" => "2023-06-01",
            "x-api-key" => SiteSetting.ai_anthropic_api_key,
            "content-type" => "application/json",
          }

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def extract_completion_from(response_raw)
          JSON.parse(response_raw, symbolize_names: true)[:completion].to_s
        end

        def partials_from(decoded_chunk)
          decoded_chunk.split("\n").map { |line| line.split("data: ", 2)[1] }.compact
        end
      end
    end
  end
end
