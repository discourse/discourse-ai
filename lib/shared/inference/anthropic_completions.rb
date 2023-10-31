# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class AnthropicCompletions
      CompletionFailed = Class.new(StandardError)
      TIMEOUT = 60

      def self.perform!(
        prompt,
        model = "claude-2",
        temperature: nil,
        top_p: nil,
        max_tokens: nil,
        user_id: nil,
        stop_sequences: nil,
        post: nil,
        &blk
      )
        # HACK to get around the fact that they have different APIs
        # we will introduce a proper LLM abstraction layer to handle this shenanigas later this year
        if model == "claude-2" && SiteSetting.ai_bedrock_access_key_id.present? &&
             SiteSetting.ai_bedrock_secret_access_key.present? &&
             SiteSetting.ai_bedrock_region.present?
          return(
            AmazonBedrockInference.perform!(
              prompt,
              temperature: temperature,
              top_p: top_p,
              max_tokens: max_tokens,
              user_id: user_id,
              stop_sequences: stop_sequences,
              &blk
            )
          )
        end

        log = nil
        response_data = +""
        response_raw = +""

        url = URI("https://api.anthropic.com/v1/complete")
        headers = {
          "anthropic-version" => "2023-06-01",
          "x-api-key" => SiteSetting.ai_anthropic_api_key,
          "content-type" => "application/json",
        }

        payload = { model: model, prompt: prompt }

        payload[:top_p] = top_p if top_p
        payload[:max_tokens_to_sample] = max_tokens || 2000
        payload[:temperature] = temperature if temperature
        payload[:stream] = true if block_given?
        payload[:stop_sequences] = stop_sequences if stop_sequences

        Net::HTTP.start(
          url.host,
          url.port,
          use_ssl: true,
          read_timeout: TIMEOUT,
          open_timeout: TIMEOUT,
          write_timeout: TIMEOUT,
        ) do |http|
          request = Net::HTTP::Post.new(url, headers)
          request_body = payload.to_json
          request.body = request_body

          http.request(request) do |response|
            if response.code.to_i != 200
              Rails.logger.error(
                "AnthropicCompletions: status: #{response.code.to_i} - body: #{response.body}",
              )
              raise CompletionFailed
            end

            log =
              AiApiAuditLog.create!(
                provider_id: AiApiAuditLog::Provider::Anthropic,
                raw_request_payload: request_body,
                user_id: user_id,
                post_id: post&.id,
                topic_id: post&.topic_id,
              )

            if !block_given?
              response_body = response.read_body
              parsed_response = JSON.parse(response_body, symbolize_names: true)

              log.update!(
                raw_response_payload: response_body,
                request_tokens: DiscourseAi::Tokenizer::AnthropicTokenizer.size(prompt),
                response_tokens:
                  DiscourseAi::Tokenizer::AnthropicTokenizer.size(parsed_response[:completion]),
              )
              return parsed_response
            end

            begin
              cancelled = false
              cancel = lambda { cancelled = true }

              response.read_body do |chunk|
                if cancelled
                  http.finish
                  return
                end

                response_raw << chunk

                chunk
                  .split("\n")
                  .each do |line|
                    data = line.split("data: ", 2)[1]
                    next if !data

                    if !cancelled
                      begin
                        partial = JSON.parse(data, symbolize_names: true)
                        response_data << partial[:completion].to_s

                        # ping has no data... do not yeild it
                        yield partial, cancel if partial[:completion]
                      rescue JSON::ParserError
                        nil
                        # TODO leftover chunk carry over to next
                      end
                    end
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
              raw_response_payload: response_raw,
              request_tokens: DiscourseAi::Tokenizer::AnthropicTokenizer.size(prompt),
              response_tokens: DiscourseAi::Tokenizer::AnthropicTokenizer.size(response_data),
            )
          end
          if Rails.env.development? && log
            puts "AnthropicCompletions: request_tokens #{log.request_tokens} response_tokens #{log.response_tokens}"
          end
        end

        def self.try_parse(data)
          JSON.parse(data, symbolize_names: true)
        rescue JSON::ParserError
          nil
        end
      end
    end
  end
end
