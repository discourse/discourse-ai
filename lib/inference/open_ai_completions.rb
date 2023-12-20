# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class OpenAiCompletions
      TIMEOUT = 60
      DEFAULT_RETRIES = 3
      DEFAULT_RETRY_TIMEOUT_SECONDS = 3
      RETRY_TIMEOUT_BACKOFF_MULTIPLIER = 3

      CompletionFailed = Class.new(StandardError)

      def self.perform!(
        messages,
        model,
        temperature: nil,
        top_p: nil,
        max_tokens: nil,
        functions: nil,
        user_id: nil,
        retries: DEFAULT_RETRIES,
        retry_timeout: DEFAULT_RETRY_TIMEOUT_SECONDS,
        post: nil,
        &blk
      )
        log = nil
        response_data = +""
        response_raw = +""

        url =
          if model.include?("gpt-4")
            if model.include?("turbo") || model.include?("1106-preview")
              URI(SiteSetting.ai_openai_gpt4_turbo_url)
            elsif model.include?("32k")
              URI(SiteSetting.ai_openai_gpt4_32k_url)
            else
              URI(SiteSetting.ai_openai_gpt4_url)
            end
          else
            if model.include?("16k")
              URI(SiteSetting.ai_openai_gpt35_16k_url)
            else
              URI(SiteSetting.ai_openai_gpt35_url)
            end
          end
        headers = { "Content-Type" => "application/json" }

        if url.host.include?("azure")
          headers["api-key"] = SiteSetting.ai_openai_api_key
        else
          headers["Authorization"] = "Bearer #{SiteSetting.ai_openai_api_key}"
        end

        if SiteSetting.ai_openai_organization.present?
          headers["OpenAI-Organization"] = SiteSetting.ai_openai_organization
        end

        payload = { model: model, messages: messages }

        payload[:temperature] = temperature if temperature
        payload[:top_p] = top_p if top_p
        payload[:max_tokens] = max_tokens if max_tokens
        payload[:functions] = functions if functions
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
            if retries > 0 && response.code.to_i == 429
              sleep(retry_timeout)
              retries -= 1
              retry_timeout *= RETRY_TIMEOUT_BACKOFF_MULTIPLIER
              return(
                perform!(
                  messages,
                  model,
                  temperature: temperature,
                  top_p: top_p,
                  max_tokens: max_tokens,
                  functions: functions,
                  user_id: user_id,
                  retries: retries,
                  retry_timeout: retry_timeout,
                  &blk
                )
              )
            elsif response.code.to_i != 200
              Rails.logger.error(
                "OpenAiCompletions: status: #{response.code.to_i} - body: #{response.body}",
              )
              raise CompletionFailed, "status: #{response.code.to_i} - body: #{response.body}"
            end

            log =
              AiApiAuditLog.create!(
                provider_id: AiApiAuditLog::Provider::OpenAI,
                raw_request_payload: request_body,
                user_id: user_id,
                post_id: post&.id,
                topic_id: post&.topic_id,
              )

            if !blk
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

              leftover = ""

              response.read_body do |chunk|
                if cancelled
                  http.finish
                  break
                end

                response_raw << chunk

                if (leftover + chunk).length < "data: [DONE]".length
                  leftover += chunk
                  next
                end

                (leftover + chunk)
                  .split("\n")
                  .each do |line|
                    data = line.split("data: ", 2)[1]
                    next if !data || data == "[DONE]"
                    next if cancelled

                    partial = nil
                    begin
                      partial = JSON.parse(data, symbolize_names: true)
                      leftover = ""
                    rescue JSON::ParserError
                      leftover = line
                    end

                    if partial
                      response_data << partial.dig(:choices, 0, :delta, :content).to_s
                      response_data << partial.dig(:choices, 0, :delta, :function_call).to_s

                      blk.call(partial, cancel)
                    end
                  end
              rescue IOError
                raise if !cancelled
              end
            end

            return response_data
          end
        end
      ensure
        if log && block_given?
          request_tokens = DiscourseAi::Tokenizer::OpenAiTokenizer.size(extract_prompt(messages))
          response_tokens = DiscourseAi::Tokenizer::OpenAiTokenizer.size(response_data)
          log.update!(
            raw_response_payload: response_raw,
            request_tokens: request_tokens,
            response_tokens: response_tokens,
          )
        end
        if log && Rails.env.development?
          puts "OpenAiCompletions: request_tokens #{log.request_tokens} response_tokens #{log.response_tokens}"
        end
      end

      def self.extract_prompt(messages)
        messages.map { |message| message[:content] || message["content"] || "" }.join("\n")
      end
    end
  end
end
