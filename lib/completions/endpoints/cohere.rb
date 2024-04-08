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

          model_params[:p] = model_params.delete(:top_p) if model_params[:top_p]

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

          @has_function_call ||= parsed.dig(:tool_calls).present?

          if @streaming_mode
            if parsed[:event_type] == "text-generation"
              parsed[:text]
            elsif parsed[:event_type] == "tool-calls-generation"
              @has_function_call = true
              parsed[:tool_calls]
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
            if @has_function_call
              parsed[:tool_calls]
            else
              parsed[:text].to_s
            end
          end
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

          function_buffer.at("function_calls").children.each(&:remove)
          function_buffer.at("function_calls").add_child(
            Nokogiri::HTML5::DocumentFragment.parse("\n"),
          )

          partial.each do |function_call|
            function_name = function_call[:name]
            parameters = function_call[:parameters]
            xml = <<~XML
              <invoke>
              <tool_name>#{function_name}</tool_name>
              <parameters>
              #{parameters.map { |k, v| "<#{k}>#{v}</#{k}>" }.join("\n")}
              </parameters>
              </invoke>
            XML

            function_buffer.at("function_calls").add_child(
              Nokogiri::HTML5::DocumentFragment.parse(xml),
            )
          end

          function_buffer
        end
      end
    end
  end
end
