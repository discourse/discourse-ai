# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class HuggingFaceTextGeneration
      CompletionFailed = Class.new(StandardError)
      TIMEOUT = 60

      def self.perform!(prompt, model, temperature: nil, top_p: nil, max_tokens: nil, user_id: nil)
        raise CompletionFailed if model.blank?

        url = URI(SiteSetting.ai_hugging_face_api_url)
        headers = { "Content-Type" => "application/json" }

        parameters = {}
        payload = { inputs: prompt, parameters: parameters }

        parameters[:top_p] = top_p if top_p
        parameters[:max_new_tokens] = max_tokens || 2000
        parameters[:temperature] = temperature if temperature
        parameters[:repetition_penalty] = 1.2
        payload[:stream] = true if block_given?

        Net::HTTP.start(
          url.host,
          url.port,
          use_ssl: url.scheme == "https",
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
                "HuggingFaceTextGeneration: status: #{response.code.to_i} - body: #{response.body}",
              )
              raise CompletionFailed
            end

            log =
              AiApiAuditLog.create!(
                provider_id: AiApiAuditLog::Provider::HuggingFaceTextGeneration,
                raw_request_payload: request_body,
                user_id: user_id,
              )

            if !block_given?
              response_body = response.read_body
              parsed_response = JSON.parse(response_body, symbolize_names: true)

              log.update!(
                raw_response_payload: response_body,
                request_tokens: DiscourseAi::Tokenizer::Llama2Tokenizer.size(prompt),
                response_tokens:
                  DiscourseAi::Tokenizer::Llama2Tokenizer.size(parsed_response[:generated_text]),
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
