# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Gemini < Base
        def self.can_contact?(model_provider)
          model_provider == "google"
        end

        def default_options
          # the default setting is a problem, it blocks too much
          categories = %w[HARASSMENT SEXUALLY_EXPLICIT HATE_SPEECH DANGEROUS_CONTENT]

          safety_settings =
            categories.map do |category|
              { category: "HARM_CATEGORY_#{category}", threshold: "BLOCK_NONE" }
            end

          { generationConfig: {}, safetySettings: safety_settings }
        end

        def normalize_model_params(model_params)
          model_params = model_params.dup

          if model_params[:stop_sequences]
            model_params[:stopSequences] = model_params.delete(:stop_sequences)
          end

          if model_params[:max_tokens]
            model_params[:maxOutputTokens] = model_params.delete(:max_tokens)
          end

          model_params[:topP] = model_params.delete(:top_p) if model_params[:top_p]

          # temperature already supported

          model_params
        end

        def provider_id
          AiApiAuditLog::Provider::Gemini
        end

        private

        def model_uri
          url = llm_model.url
          key = llm_model.api_key

          if @streaming_mode
            url = "#{url}:streamGenerateContent?key=#{key}&alt=sse"
          else
            url = "#{url}:generateContent?key=#{key}"
          end

          URI(url)
        end

        def prepare_payload(prompt, model_params, dialect)
          tools = dialect.tools

          payload = default_options.merge(contents: prompt[:messages])
          payload[:systemInstruction] = {
            role: "system",
            parts: [{ text: prompt[:system_instruction].to_s }],
          } if prompt[:system_instruction].present?
          if tools.present?
            payload[:tools] = tools

            function_calling_config = { mode: "AUTO" }
            if dialect.tool_choice.present?
              function_calling_config = {
                mode: "ANY",
                allowed_function_names: [dialect.tool_choice],
              }
            end

            payload[:tool_config] = { function_calling_config: function_calling_config }
          end
          payload[:generationConfig].merge!(model_params) if model_params.present?
          payload
        end

        def prepare_request(payload)
          headers = { "Content-Type" => "application/json" }

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def extract_completion_from(response_raw)
          parsed =
            if @streaming_mode
              response_raw
            else
              JSON.parse(response_raw, symbolize_names: true)
            end
          response_h = parsed.dig(:candidates, 0, :content, :parts, 0)

          if response_h
            @has_function_call ||= response_h.dig(:functionCall).present?
            @has_function_call ? response_h.dig(:functionCall) : response_h.dig(:text)
          end
        end

        def partials_from(decoded_chunk)
          decoded_chunk
        end

        def chunk_to_string(chunk)
          chunk.to_s
        end

        class Decoder
          def initialize
            @buffer = +""
          end

          def decode(str)
            @buffer << str

            lines = @buffer.split(/\r?\n\r?\n/)

            keep_last = false

            decoded =
              lines
                .map do |line|
                  if line.start_with?("data: {")
                    begin
                      JSON.parse(line[6..-1], symbolize_names: true)
                    rescue JSON::ParserError
                      keep_last = line
                      nil
                    end
                  else
                    keep_last = line
                    nil
                  end
                end
                .compact

            if keep_last
              @buffer = +(keep_last)
            else
              @buffer = +""
            end

            decoded
          end
        end

        def decode(chunk)
          @decoder ||= Decoder.new
          @decoder.decode(chunk)
        end

        def extract_prompt_for_tokenizer(prompt)
          prompt.to_s
        end

        def has_tool?(_response_data)
          @has_function_call
        end

        def native_tool_support?
          true
        end

        def add_to_function_buffer(function_buffer, payload: nil, partial: nil)
          if @streaming_mode
            return function_buffer if !partial
          else
            partial = payload
          end

          function_buffer.at("tool_name").content = partial[:name] if partial[:name].present?

          if partial[:args]
            argument_fragments =
              partial[:args].reduce(+"") do |memo, (arg_name, value)|
                memo << "\n<#{arg_name}>#{value}</#{arg_name}>"
              end
            argument_fragments << "\n"

            function_buffer.at("parameters").children =
              Nokogiri::HTML5::DocumentFragment.parse(argument_fragments)
          end

          function_buffer
        end
      end
    end
  end
end
