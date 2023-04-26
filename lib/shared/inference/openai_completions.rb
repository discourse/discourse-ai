# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class OpenAiCompletions
      TIMEOUT = 60

      CompletionFailed = Class.new(StandardError)

      def self.perform!(
        messages,
        model = SiteSetting.ai_helper_model,
        temperature: nil,
        top_p: nil,
        max_tokens: nil,
        stream: false,
        user_id: nil,
        &blk
      )
        raise ArgumentError, "block must be supplied in streaming mode" if stream && !blk

        url = URI("https://api.openai.com/v1/chat/completions")
        headers = {
          "Content-Type": "application/json",
          Authorization: "Bearer #{SiteSetting.ai_openai_api_key}",
        }
        payload = { model: model, messages: messages }

        payload[:temperature] = temperature if temperature
        payload[:top_p] = top_p if top_p
        payload[:max_tokens] = max_tokens if max_tokens
        payload[:stream] = true if stream

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

          response = http.request(request)

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

          if stream
            stream(http, response, messages, log, &blk)
          else
            response_body = response.body
            parsed = JSON.parse(response_body, symbolize_names: true)

            log.update!(
              raw_response_payload: response_body,
              request_tokens: parsed.dig(:usage, :prompt_tokens),
              response_tokens: parsed.dig(:usage, :completion_tokens),
            )
            parsed
          end
        end
      end

      def self.stream(http, response, messages, log)
        cancelled = false
        cancel = lambda { cancelled = true }

        response_data = +""
        response_raw = +""

        response.read_body do |chunk|
          if cancelled
            http.finish
            break
          end

          response_raw << chunk

          chunk
            .split("\n")
            .each do |line|
              data = line.split("data: ", 2)[1]

              next if data == "[DONE]"

              if data
                json = JSON.parse(data, symbolize_names: true)
                choices = json[:choices]
                if choices && choices[0]
                  delta = choices[0].dig(:delta, :content)
                  response_data << delta if delta
                end
                yield json, cancel
              end

              if cancelled
                http.finish
                break
              end
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

      def self.extract_prompt(messages)
        messages.map { |message| message[:content] || message["content"] || "" }.join("\n")
      end
    end
  end
end
