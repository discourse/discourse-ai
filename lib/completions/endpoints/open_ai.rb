# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class OpenAi < Base
        class << self
          def can_contact?(endpoint_name)
            endpoint_name == "open_ai"
          end

          def dependant_setting_names
            %w[
              ai_openai_api_key
              ai_openai_gpt4o_url
              ai_openai_gpt4_32k_url
              ai_openai_gpt4_turbo_url
              ai_openai_gpt4_url
              ai_openai_gpt4_url
              ai_openai_gpt35_16k_url
              ai_openai_gpt35_url
            ]
          end

          def correctly_configured?(model_name)
            SiteSetting.ai_openai_api_key.present? && has_url?(model_name)
          end

          def has_url?(model)
            url =
              if model.include?("gpt-4")
                if model.include?("32k")
                  SiteSetting.ai_openai_gpt4_32k_url
                else
                  if model.include?("1106") || model.include?("turbo")
                    SiteSetting.ai_openai_gpt4_turbo_url
                  elsif model.include?("gpt-4o")
                    SiteSetting.ai_openai_gpt4o_url
                  else
                    SiteSetting.ai_openai_gpt4_url
                  end
                end
              else
                if model.include?("16k")
                  SiteSetting.ai_openai_gpt35_16k_url
                else
                  SiteSetting.ai_openai_gpt35_url
                end
              end

            url.present?
          end

          def endpoint_name(model_name)
            "OpenAI - #{model_name}"
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
          { model: model }
        end

        def provider_id
          AiApiAuditLog::Provider::OpenAI
        end

        private

        def model_uri
          return URI(llm_model.url) if llm_model&.url

          url =
            if model.include?("gpt-4")
              if model.include?("32k")
                SiteSetting.ai_openai_gpt4_32k_url
              else
                if model.include?("1106") || model.include?("turbo")
                  SiteSetting.ai_openai_gpt4_turbo_url
                else
                  SiteSetting.ai_openai_gpt4_url
                end
              end
            else
              if model.include?("16k")
                SiteSetting.ai_openai_gpt35_16k_url
              else
                SiteSetting.ai_openai_gpt35_url
              end
            end

          URI(url)
        end

        def prepare_payload(prompt, model_params, dialect)
          payload = default_options.merge(model_params).merge(messages: prompt)

          if @streaming_mode
            payload[:stream] = true

            # Usage is not available in Azure yet.
            # We'll fallback to guess this using the tokenizer.
            payload[:stream_options] = { include_usage: true } if model_uri.host.exclude?("azure")
          end

          payload[:tools] = dialect.tools if dialect.tools.present?
          payload
        end

        def prepare_request(payload)
          headers = { "Content-Type" => "application/json" }

          api_key = llm_model&.api_key || SiteSetting.ai_openai_api_key

          if model_uri.host.include?("azure")
            headers["api-key"] = api_key
          else
            headers["Authorization"] = "Bearer #{api_key}"
          end

          org_id =
            llm_model&.lookup_custom_param("organization") || SiteSetting.ai_openai_organization
          headers["OpenAI-Organization"] = org_id if org_id.present?

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def final_log_update(log)
          log.request_tokens = @prompt_tokens if @prompt_tokens
          log.response_tokens = @completion_tokens if @completion_tokens
        end

        def extract_completion_from(response_raw)
          json = JSON.parse(response_raw, symbolize_names: true)

          if @streaming_mode
            @prompt_tokens ||= json.dig(:usage, :prompt_tokens)
            @completion_tokens ||= json.dig(:usage, :completion_tokens)
          end

          parsed = json.dig(:choices, 0)
          return if !parsed

          response_h = @streaming_mode ? parsed.dig(:delta) : parsed.dig(:message)
          @has_function_call ||= response_h.dig(:tool_calls).present?
          @has_function_call ? response_h.dig(:tool_calls, 0) : response_h.dig(:content)
        end

        def partials_from(decoded_chunk)
          decoded_chunk
            .split("\n")
            .map do |line|
              data = line.split("data: ", 2)[1]
              data == "[DONE]" ? nil : data
            end
            .compact
        end

        def has_tool?(_response_data)
          @has_function_call
        end

        def native_tool_support?
          true
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
