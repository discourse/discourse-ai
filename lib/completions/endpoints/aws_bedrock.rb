# frozen_string_literal: true

require "aws-sigv4"

module DiscourseAi
  module Completions
    module Endpoints
      class AwsBedrock < Base
        class << self
          def can_contact?(endpoint_name)
            endpoint_name == "aws_bedrock"
          end

          def dependant_setting_names
            %w[ai_bedrock_access_key_id ai_bedrock_secret_access_key ai_bedrock_region]
          end

          def correctly_configured?(_model)
            return false
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

          # max_tokens, temperature, stop_sequences, top_p are already supported

          model_params
        end

        def default_options(dialect)
          options = { max_tokens: 3_000, anthropic_version: "bedrock-2023-05-31" }
          options
        end

        def provider_id
          AiApiAuditLog::Provider::Anthropic
        end

        private

        def prompt_size(prompt)
          # approximation
          tokenizer.size(prompt.system_prompt.to_s + " " + prompt.messages.to_s)
        end

        def model_uri
          # See: https://docs.aws.amazon.com/bedrock/latest/userguide/model-ids-arns.html
          #
          # FYI there is a 2.0 version of Claude, very little need to support it given
          # haiku/sonnet are better fits anyway, we map to claude-2.1
          bedrock_model_id =
            case model
            when "claude-2"
              "anthropic.claude-v2:1"
            when "claude-3-haiku"
              "anthropic.claude-3-haiku-20240307-v1:0"
            when "claude-3-sonnet"
              "anthropic.claude-3-sonnet-20240229-v1:0"
            when "claude-instant-1"
              "anthropic.claude-instant-v1"
            when "claude-3-opus"
              "anthropic.claude-3-opus-20240229-v1:0"
            end

          api_url =
            llm_model&.url ||
              "https://bedrock-runtime.#{SiteSetting.ai_bedrock_region}.amazonaws.com/model/#{bedrock_model_id}/invoke"

          api_url = @streaming_mode ? (api_url + "-with-response-stream") : api_url

          URI(api_url)
        end

        def prepare_payload(prompt, model_params, dialect)
          payload = default_options(dialect).merge(model_params).merge(messages: prompt.messages)
          payload[:system] = prompt.system_prompt if prompt.system_prompt.present?
          payload[:tools] = prompt.tools if prompt.tools.present?

          payload
        end

        def prepare_request(payload)
          headers = { "content-type" => "application/json", "Accept" => "*/*" }

          signer =
            Aws::Sigv4::Signer.new(
              access_key_id: SiteSetting.ai_bedrock_access_key_id,
              region: SiteSetting.ai_bedrock_region,
              secret_access_key: llm_model&.api_key || SiteSetting.ai_bedrock_secret_access_key,
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
          @decoder ||= Aws::EventStream::Decoder.new

          decoded, _done = @decoder.decode_chunk(chunk)

          messages = []
          return messages if !decoded

          i = 0
          while decoded
            parsed = JSON.parse(decoded.payload.string)
            # perhaps some control message we can just ignore
            messages << Base64.decode64(parsed["bytes"]) if parsed && parsed["bytes"]

            decoded, _done = @decoder.decode_chunk

            i += 1
            if i > 10_000
              Rails.logger.error(
                "DiscourseAI: Stream decoder looped too many times, logic error needs fixing",
              )
              break
            end
          end

          messages
        rescue JSON::ParserError,
               Aws::EventStream::Errors::MessageChecksumError,
               Aws::EventStream::Errors::PreludeChecksumError => e
          Rails.logger.error("#{self.class.name}: #{e.message}")
          nil
        end

        def final_log_update(log)
          log.request_tokens = processor.input_tokens if processor.input_tokens
          log.response_tokens = processor.output_tokens if processor.output_tokens
        end

        def processor
          @processor ||=
            DiscourseAi::Completions::AnthropicMessageProcessor.new(streaming_mode: @streaming_mode)
        end

        def add_to_function_buffer(function_buffer, partial: nil, payload: nil)
          x = processor.to_xml_tool_calls(function_buffer)
          p x.to_s
          x
        end

        def extract_completion_from(response_raw)
          p "HERE1"
          puts response_raw
          p "HERE2"
          processor.process_message(response_raw)
        end

        def has_tool?(_response_data)
          processor.tool_calls.present?
        end

        def partials_from(decoded_chunks)
          decoded_chunks
        end

        def native_tool_support?
          true
        end

        def chunk_to_string(chunk)
          joined = +chunk.join("\n")
          joined << "\n" if joined.length > 0
          joined
        end
      end
    end
  end
end
