# frozen_string_literal: true

require "aws-sigv4"

module DiscourseAi
  module Completions
    module Endpoints
      class AwsBedrock < Base
        class << self
          def can_contact?(endpoint_name, model_name)
            endpoint_name == "aws_bedrock" && %w[claude-instant-1 claude-2].include?(model_name)
          end

          def dependant_setting_names
            %w[ai_bedrock_access_key_id ai_bedrock_secret_access_key ai_bedrock_region]
          end

          def correctly_configured?(_model_name)
            SiteSetting.ai_bedrock_access_key_id.present? &&
              SiteSetting.ai_bedrock_secret_access_key.present? &&
              SiteSetting.ai_bedrock_region.present?
          end

          def endpoint_name(model_name)
            "AWS Bedrock - #{model_name}"
          end
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
          { max_tokens_to_sample: 3_000, stop_sequences: ["\n\nHuman:", "</function_calls>"] }
        end

        def provider_id
          AiApiAuditLog::Provider::Anthropic
        end

        private

        def model_uri
          # Bedrock uses slightly different names
          # See: https://docs.aws.amazon.com/bedrock/latest/userguide/model-ids-arns.html
          bedrock_model_id = model.split("-")
          bedrock_model_id[-1] = "v#{bedrock_model_id.last}"
          bedrock_model_id = +(bedrock_model_id.join("-"))

          bedrock_model_id << ":1" if model == "claude-2" # For claude-2.1

          api_url =
            "https://bedrock-runtime.#{SiteSetting.ai_bedrock_region}.amazonaws.com/model/anthropic.#{bedrock_model_id}/invoke"

          api_url = @streaming_mode ? (api_url + "-with-response-stream") : api_url

          URI(api_url)
        end

        def prepare_payload(prompt, model_params, _dialect)
          default_options.merge(prompt: prompt).merge(model_params)
        end

        def prepare_request(payload)
          headers = { "content-type" => "application/json", "Accept" => "*/*" }

          signer =
            Aws::Sigv4::Signer.new(
              access_key_id: SiteSetting.ai_bedrock_access_key_id,
              region: SiteSetting.ai_bedrock_region,
              secret_access_key: SiteSetting.ai_bedrock_secret_access_key,
              service: "bedrock",
            )

          Net::HTTP::Post
            .new(model_uri)
            .tap do |r|
              r.body = payload

              signed_request =
                signer.sign_request(req: r, http_method: r.method, url: model_uri, body: r.body)

              r.initialize_http_header(headers.merge(signed_request.headers))
            end
        end

        def decode(chunk)
          parsed =
            Aws::EventStream::Decoder
              .new
              .decode_chunk(chunk)
              .first
              .payload
              .string
              .then { JSON.parse(_1) }

          bytes = parsed.dig("bytes")

          if !bytes
            Rails.logger.error("#{self.class.name}: #{parsed.to_s[0..500]}")
            nil
          else
            Base64.decode64(parsed.dig("bytes"))
          end
        rescue JSON::ParserError,
               Aws::EventStream::Errors::MessageChecksumError,
               Aws::EventStream::Errors::PreludeChecksumError => e
          Rails.logger.error("#{self.class.name}: #{e.message}")
          nil
        end

        def extract_completion_from(response_raw)
          JSON.parse(response_raw, symbolize_names: true)[:completion].to_s
        end

        def partials_from(decoded_chunk)
          [decoded_chunk]
        end
      end
    end
  end
end
