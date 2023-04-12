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
        &blk
      )
        raise ArgumentError, "block must be supplied in streaming mode" if stream && !blk

        url = URI("https://api.openai.com/v1/chat/completions")
        headers = {
          "Content-Type": "application/json",
          Authorization: "Bearer #{SiteSetting.ai_openai_api_key}",
        }
        payload = { model: SiteSetting.blog_open_ai_model, messages: messages }

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
          request.body = payload.to_json

          response = http.request(request)

          if response.code.to_i != 200
            Rails.logger.error(
              "OpenAiCompletions: status: #{response.status} - body: #{response.body}",
            )
            raise CompletionFailed
          end

          if stream
            stream(http, response, &blk)
          else
            JSON.parse(response.read_body, symbolize_names: true)
          end
        end
      end

      def self.stream(http, response)
        cancelled = false
        cancel = lambda { cancelled = true }

        response.read_body do |chunk|
          if cancelled
            http.finish
            break
          end

          chunk
            .split("\n")
            .each do |line|
              data = line.split("data: ", 2)[1]

              next if data == "[DONE]"

              yield JSON.parse(data, symbolize_names: true), cancel if data

              if cancelled
                http.finish
                break
              end
            end
        end
      rescue IOError
        raise if !cancelled
      end
    end
  end
end
