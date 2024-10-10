# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Ollama < Base
        def self.can_contact?(model_provider)
          model_provider == "ollama"
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
          { max_tokens: 2000, model: llm_model.name }
        end

        def provider_id
          AiApiAuditLog::Provider::Ollama
        end

        def use_ssl?
          false
        end

        private

        def model_uri
          URI(llm_model.url)
        end

        def native_tool_support?
          @native_tool_support
        end

        def has_tool?(_response_data)
          @has_function_call
        end

        def prepare_payload(prompt, model_params, dialect)
          @native_tool_support = dialect.native_tool_support?

          # https://github.com/ollama/ollama/blob/main/docs/api.md#parameters-1
          # Due to ollama enforce a 'stream: false' for tool calls, instead of complicating the code,
          # we will just disable streaming for all ollama calls if native tool support is enabled

          default_options
            .merge(model_params)
            .merge(messages: prompt)
            .tap { |payload| payload[:stream] = false if @native_tool_support || !@streaming_mode }
            .tap { |payload| payload[:tools] = dialect.tools if @native_tool_support && dialect.tools.present? }
        end

        def prepare_request(payload)
          headers = { "Content-Type" => "application/json" }

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def partials_from(decoded_chunk)
          decoded_chunk.split("\n").compact
        end

        def extract_completion_from(response_raw)
          parsed = JSON.parse(response_raw, symbolize_names: true)
          return if !parsed

          response_h = parsed.dig(:message)

          @has_function_call ||= response_h.dig(:tool_calls).present?
          @has_function_call ? response_h.dig(:tool_calls, 0) : response_h.dig(:content)
        end

        def add_to_function_buffer(function_buffer, payload: nil, partial: nil)
          @args_buffer ||= +""

          if @streaming_mode
            return function_buffer if !partial
          else
            partial = payload
          end

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
            @args_buffer << args.to_json

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
