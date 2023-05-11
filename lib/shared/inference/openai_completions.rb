# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class OpenAiCompletions
      TIMEOUT = 60

      CompletionFailed = Class.new(StandardError)

      def self.perform!(
        messages,
        model,
        temperature: nil,
        top_p: nil,
        max_tokens: nil,
        user_id: nil
      )
        url = URI("https://api.openai.com/v1/chat/completions")
        headers = {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{SiteSetting.ai_openai_api_key}",
        }

        payload = { model: model, messages: messages }

        payload[:temperature] = temperature if temperature
        payload[:top_p] = top_p if top_p
        payload[:max_tokens] = max_tokens if max_tokens
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
                "OpenAiCompletions: status: #{response.code.to_i} - body: #{response.body}",
              )
              raise CompletionFailed
            end

            log =
              AiApiAuditLog.create!(
                provider_id: AiApiAuditLog::Provider::OpenAI,
                raw_request_payload: request_body,
                user_id: user_id,
              )

            if !block_given?
              response_body = response.read_body
              parsed_response = JSON.parse(response_body, symbolize_names: true)

              log.update!(
                raw_response_payload: response_body,
                request_tokens: parsed_response.dig(:usage, :prompt_tokens),
                response_tokens: parsed_response.dig(:usage, :completion_tokens),
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
                    next if !data || data == "[DONE]"

                    if !cancelled && partial = JSON.parse(data, symbolize_names: true)
                      response_data << partial.dig(:choices, 0, :delta, :content).to_s

                      yield partial, cancel
                    end
                  end
              rescue IOError
                raise if !cancelled
              ensure
                log.update!(
                  raw_response_payload: response_raw,
                  request_tokens: DiscourseAi::Tokenizer.size(extract_prompt(messages)),
                  response_tokens: DiscourseAi::Tokenizer.size(response_data),
                )
              end
            end
          end
        end
      end

      def self.extract_prompt(messages)
        messages.map { |message| message[:content] || message["content"] || "" }.join("\n")
      end
    end
  end
end
