# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class OpenAiCompletions
      TIMEOUT = 60

      class Function
        attr_reader :name, :description, :parameters, :type

        def initialize(name:, description:, type: nil)
          @name = name
          @description = description
          @type = type || "object"
          @parameters = []
        end

        def add_parameter(name:, type:, description:, enum: nil, required: false)
          @parameters << {
            name: name,
            type: type,
            description: description,
            enum: enum,
            required: required,
          }
        end

        def to_json(*args)
          as_json.to_json(*args)
        end

        def as_json
          required_params = []

          properties = {}
          parameters.each do |parameter|
            definition = { type: parameter[:type], description: parameter[:description] }
            definition[:enum] = parameter[:enum] if parameter[:enum]

            required_params << parameter[:name] if parameter[:required]
            properties[parameter[:name]] = definition
          end

          params = { type: @type, properties: properties }

          params[:required] = required_params if required_params.present?

          { name: name, description: description, parameters: params }
        end
      end

      CompletionFailed = Class.new(StandardError)

      def self.perform!(
        messages,
        model,
        temperature: nil,
        top_p: nil,
        max_tokens: nil,
        functions: nil,
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
            if response.code.to_i != 200
              puts response.body
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

              leftover = ""

              response.read_body do |chunk|
                if cancelled
                  http.finish
                  return
                end

                response_raw << chunk

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

                      yield partial, cancel
                    end
                  end
              rescue IOError
                raise if !cancelled
              ensure
                log.update!(
                  raw_response_payload: response_raw,
                  request_tokens:
                    DiscourseAi::Tokenizer::OpenAiTokenizer.size(extract_prompt(messages)),
                  response_tokens: DiscourseAi::Tokenizer::OpenAiTokenizer.size(response_data),
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
