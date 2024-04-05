# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Cohere < Base
        class << self
          def can_contact?(endpoint_name, model_name)
            return false unless endpoint_name == "cohere"

            %w[command-light command command-r command-r-plus].include?(model_name)
          end

          def dependant_setting_names
            %w[ai_cohere_api_key]
          end

          def correctly_configured?(model_name)
            SiteSetting.ai_cohere_api_key.present?
          end

          def endpoint_name(model_name)
            "Cohere - #{model_name}"
          end
        end

        def normalize_model_params(model_params)
          model_params = model_params.dup

          # max_tokens, temperature are already supported
          if model_params[:stop_sequences]
            model_params[:stop] = model_params.delete(:stop_sequences)
          end

          model_params
        end

        def default_options
          { model: "command-r-plus" }
        end

        def provider_id
          AiApiAuditLog::Provider::Cohere
        end

        private

        def model_uri
          URI("https://api.cohere.ai/v1/chat")
        end

        def prepare_payload(prompt, model_params, dialect)
          payload = default_options.merge(model_params).merge(prompt)

          payload[:stream] = true if @streaming_mode
          payload[:tools] = dialect.tools if dialect.tools.present?

          payload
        end

        def prepare_request(payload)
          headers = {
            "Content-Type" => "application/json",
            "Authorization" => "Bearer #{SiteSetting.ai_cohere_api_key}",
          }

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def extract_completion_from(response_raw)
          parsed = JSON.parse(response_raw, symbolize_names: true)

          if @streaming_mode
            if parsed[:event_type] == "text-generation"
              parsed[:text]
            else
              if parsed[:event_type] == "stream-end"
                @input_tokens = parsed.dig(:response, :meta, :billed_units, :input_tokens)
                @output_tokens = parsed.dig(:response, :meta, :billed_units, :output_tokens)
              end
              nil
            end
          else
            @input_tokens = parsed.dig(:meta, :billed_units, :input_tokens)
            @output_tokent = parsed.dig(:meta, :billed_units, :output_tokens)
            parsed[:text]
          end

          #@has_function_call ||= response_h.dig(:tool_calls).present?
          #@has_function_call ? response_h.dig(:tool_calls, 0) : response_h.dig(:content)
        end

        def final_log_update(log)
          log.request_tokens = @input_tokens if @input_tokens
          log.response_tokens = @output_tokens if @output_tokens
        end

        def partials_from(decoded_chunk)
          decoded_chunk.split("\n").compact
        end

        def extract_prompt_for_tokenizer(prompt)
          text = +""
          if prompt[:chat_history]
            text << prompt[:chat_history]
              .map { |message| message[:content] || message["content"] || "" }
              .join("\n")
          end

          text << prompt[:message] if prompt[:message]
          text << prompt[:preamble] if prompt[:preamble]

          text
        end

        def has_tool?(_response_data)
          @has_function_call
        end

        def maybe_has_tool?(_partial_raw)
          # we always get a full partial
          false
        end

        def add_to_function_buffer(function_buffer, partial: nil, payload: nil)
          if @streaming_mode
            return function_buffer if !partial
          else
            partial = payload
          end

          @args_buffer ||= +""

          f_name = partial.dig(:function, :name)

          @current_function ||= function_buffer.at("invoke")

          if f_name
            current_name = function_buffer.at("tool_name").content

            if current_name.blank?
              # first call
            else
              # we have a previous function, so we need to add a noop
              @args_buffer = +""
              @current_function =
                function_buffer.at("function_calls").add_child(
                  Nokogiri::HTML5::DocumentFragment.parse(noop_function_call_text + "\n"),
                )
            end
          end

          @current_function.at("tool_name").content = f_name if f_name
          @current_function.at("tool_id").content = partial[:id] if partial[:id]

          args = partial.dig(:function, :arguments)

          # allow for SPACE within arguments
          if args && args != ""
            @args_buffer << args

            begin
              json_args = JSON.parse(@args_buffer, symbolize_names: true)

              argument_fragments =
                json_args.reduce(+"") do |memo, (arg_name, value)|
                  memo << "\n<#{arg_name}>#{value}</#{arg_name}>"
                end
              argument_fragments << "\n"

              @current_function.at("parameters").children =
                Nokogiri::HTML5::DocumentFragment.parse(argument_fragments)
            rescue JSON::ParserError
              return function_buffer
            end
          end

          function_buffer
        end
      end
    end
  end
end
