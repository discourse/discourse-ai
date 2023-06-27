# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class AnthropicCompletions
      CompletionFailed = Class.new(StandardError)
      TIMEOUT = 60

      def self.perform!(
        prompt,
        model = "claude-v1",
        temperature: nil,
        top_p: nil,
        max_tokens: nil,
        user_id: nil
      )
        url = URI("https://api.anthropic.com/v1/complete")
        headers = {
          "x-api-key" => SiteSetting.ai_anthropic_api_key,
          "Content-Type" => "application/json",
        }

        payload = { model: model, prompt: prompt }

        payload[:temperature] = temperature if temperature
        payload[:top_p] = top_p if top_p
        payload[:max_tokens_to_sample] = max_tokens if max_tokens
        payload[:stream] = true if block_given?

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
              response_data = +""
              response_raw = +""

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
                    next if !data || data.squish == "[DONE]"

                    if !cancelled
                      begin
                        # partial contains the entire payload till now
                        partial = JSON.parse(data, symbolize_names: true)
                        response_data = partial[:completion].to_s

                        yield partial, cancel
                      rescue JSON::ParserError
                        nil
                      end
                    end
                  end
              rescue IOError
                raise if !cancelled
              ensure
                log.update!(
                  raw_response_payload: response_raw,
                  request_tokens: DiscourseAi::Tokenizer::AnthropicTokenizer.size(prompt),
                  response_tokens: DiscourseAi::Tokenizer::AnthropicTokenizer.size(response_data),
                )
              end
            end
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
