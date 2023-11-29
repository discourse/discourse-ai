# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Anthropic < Base
        def self.can_contact?(model_name)
          %w[claude-instant-1 claude-2].include?(model_name)
        end

        def default_options
          { max_tokens_to_sample: 2000, model: model }
        end

        def provider_id
          AiApiAuditLog::Provider::Anthropic
        end

        private

        def model_uri
          @uri ||= URI("https://api.anthropic.com/v1/complete")
        end

        def prepare_payload(prompt, model_params)
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
