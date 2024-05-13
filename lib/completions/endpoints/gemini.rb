# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Gemini < Base
        class << self
          def can_contact?(endpoint_name)
            endpoint_name == "google"
          end

          def dependant_setting_names
            %w[ai_gemini_api_key]
          end

          def correctly_configured?(_model_name)
            SiteSetting.ai_gemini_api_key.present?
          end

          def endpoint_name(model_name)
            "Google - #{model_name}"
          end
        end

        def default_options
          { generationConfig: {} }
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
          mapped_model = model == "gemini-1.5-pro" ? "gemini-1.5-pro-latest" : model
          url =
            "https://generativelanguage.googleapis.com/v1beta/models/#{mapped_model}:#{@streaming_mode ? "streamGenerateContent" : "generateContent"}?key=#{SiteSetting.ai_gemini_api_key}"

          URI(url)
        end

        def prepare_payload(prompt, model_params, dialect)
          tools = dialect.tools

          default_options
            .merge(contents: prompt)
            .tap do |payload|
              payload[:tools] = tools if tools.present?
              payload[:generationConfig].merge!(model_params) if model_params.present?
            end
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

          @has_function_call ||= response_h.dig(:functionCall).present?
          @has_function_call ? response_h[:functionCall] : response_h.dig(:text)
        end

        def partials_from(decoded_chunk)
          begin
            JSON.parse(decoded_chunk, symbolize_names: true)
          rescue JSON::ParserError
            []
          end
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
