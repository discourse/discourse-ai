# frozen_string_literal: true

require "base64"
require "json"
require "aws-eventstream"
require "aws-sigv4"

module ::DiscourseAi
  module Inference
    class AmazonBedrockInference
      CompletionFailed = Class.new(StandardError)
      TIMEOUT = 60

      def self.perform!(
        prompt,
        model = "anthropic.claude-v2",
        temperature: nil,
        top_p: nil,
        top_k: nil,
        max_tokens: 20_000,
        user_id: nil,
        stop_sequences: nil,
        tokenizer: Tokenizer::AnthropicTokenizer
      )
        raise CompletionFailed if model.blank?
        raise CompletionFailed if !SiteSetting.ai_bedrock_access_key_id.present?
        raise CompletionFailed if !SiteSetting.ai_bedrock_secret_access_key.present?
        raise CompletionFailed if !SiteSetting.ai_bedrock_region.present?

        signer =
          Aws::Sigv4::Signer.new(
            access_key_id: SiteSetting.ai_bedrock_access_key_id,
            region: SiteSetting.ai_bedrock_region,
            secret_access_key: SiteSetting.ai_bedrock_secret_access_key,
            service: "bedrock",
          )

        log = nil
        response_data = +""
        response_raw = +""

        url_api = "https://bedrock-runtime.#{SiteSetting.ai_bedrock_region}.amazonaws.com/model/#{model}/"
        if block_given?
          url_api = url_api + "invoke-with-response-stream"
        else
          url_api = url_api + "invoke"
        end

        url = URI(url_api)
        headers = { "content-type" => "application/json", "Accept" => "*/*" }

        payload = { prompt: prompt }

        payload[:top_p] = top_p if top_p
        payload[:top_k] = top_k if top_k
        payload[:max_tokens_to_sample] = max_tokens || 2000
        payload[:temperature] = temperature if temperature
        payload[:stop_sequences] = stop_sequences if stop_sequences

        Net::HTTP.start(
          url.host,
          url.port,
          use_ssl: true,
          read_timeout: TIMEOUT,
          open_timeout: TIMEOUT,
          write_timeout: TIMEOUT,
        ) do |http|
          request = Net::HTTP::Post.new(url)
          request_body = payload.to_json
          request.body = request_body

          signed_request =
            signer.sign_request(
              req: request,
              http_method: request.method,
              url: url,
              body: request.body,
            )

          request.initialize_http_header(headers.merge!(signed_request.headers))

          http.request(request) do |response|
            if response.code.to_i != 200
              Rails.logger.error(
                "BedRockInference: status: #{response.code.to_i} - body: #{response.body}",
              )
              raise CompletionFailed
            end

            log =
              AiApiAuditLog.create!(
                provider_id: AiApiAuditLog::Provider::Anthropic,
                raw_request_payload: request_body,
                user_id: user_id,
              )

            if !block_given?
              response_body = response.read_body
              parsed_response = JSON.parse(response_body, symbolize_names: true)

              log.update!(
                raw_response_payload: response_body,
                request_tokens: tokenizer.size(prompt),
                response_tokens: tokenizer.size(parsed_response[:completion]),
              )
              return parsed_response
            end

            begin
              cancelled = false
              cancel = lambda { cancelled = true }
              decoder = Aws::EventStream::Decoder.new

              response.read_body do |chunk|
                if cancelled
                  http.finish
                  return
                end

                response_raw << chunk

                begin
                  message = decoder.decode_chunk(chunk)

                  partial =
                    message
                      .first
                      .payload
                      .string
                      .then { JSON.parse(_1) }
                      .dig("bytes")
                      .then { Base64.decode64(_1) }
                      .then { JSON.parse(_1, symbolize_names: true) }

                  next if !partial

                  response_data << partial[:completion].to_s

                  yield partial, cancel if partial[:completion]
                rescue JSON::ParserError,
                       Aws::EventStream::Errors::MessageChecksumError,
                       Aws::EventStream::Errors::PreludeChecksumError => e
                  Rails.logger.error("BedrockInference: #{e}")
                end
              rescue IOError
                raise if !cancelled
              end
            end

            return response_data
          end
        ensure
          if block_given?
            log.update!(
              raw_response_payload: response_data,
              request_tokens: tokenizer.size(prompt),
              response_tokens: tokenizer.size(response_data),
            )
          end
          if Rails.env.development? && log
            puts "BedrockInference: request_tokens #{log.request_tokens} response_tokens #{log.response_tokens}"
          end
        end
      end
    end
  end
end
