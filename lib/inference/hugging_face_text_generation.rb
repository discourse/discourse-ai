# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class HuggingFaceTextGeneration
      CompletionFailed = Class.new(StandardError)
      TIMEOUT = 120

      def self.perform!(
        prompt,
        model,
        temperature: 0.7,
        top_p: nil,
        top_k: nil,
        typical_p: nil,
        max_tokens: 2000,
        repetition_penalty: 1.1,
        user_id: nil,
        tokenizer: DiscourseAi::Tokenizer::Llama2Tokenizer,
        token_limit: nil
      )
        raise CompletionFailed if model.blank?

        url = URI(SiteSetting.ai_hugging_face_api_url)
        headers = { "Content-Type" => "application/json" }

        if SiteSetting.ai_hugging_face_api_key.present?
          headers["Authorization"] = "Bearer #{SiteSetting.ai_hugging_face_api_key}"
        end

        token_limit = token_limit || SiteSetting.ai_hugging_face_token_limit

        parameters = {}
        payload = { inputs: prompt, parameters: parameters }
        prompt_size = tokenizer.size(prompt)

        parameters[:top_p] = top_p if top_p
        parameters[:top_k] = top_k if top_k
        parameters[:typical_p] = typical_p if typical_p
        parameters[:max_new_tokens] = token_limit - prompt_size
        parameters[:temperature] = temperature if temperature
        parameters[:repetition_penalty] = repetition_penalty if repetition_penalty
        parameters[:return_full_text] = false

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
                request_tokens: tokenizer.size(prompt),
                response_tokens: tokenizer.size(parsed_response.first[:generated_text]),
              )
              return parsed_response
            end

            response_data = +""

            begin
              cancelled = false
              cancel = lambda { cancelled = true }
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
                    data = line.split("data:", 2)[1]
                    next if !data || data.squish == "[DONE]"

                    if !cancelled
                      begin
                        # partial contains the entire payload till now
                        partial = JSON.parse(data, symbolize_names: true)

                        # this is the last chunk and contains the full response
                        next if partial[:token][:special] == true

                        response_data << partial[:token][:text].to_s

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
                  request_tokens: tokenizer.size(prompt),
                  response_tokens: tokenizer.size(response_data),
                )
              end
            end

            return response_data
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
