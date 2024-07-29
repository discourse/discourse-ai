# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Cohere < Base
        def self.can_contact?(model_provider)
          model_provider == "cohere"
        end

        def normalize_model_params(model_params)
          model_params = model_params.dup
          model_params[:p] = model_params.delete(:top_p) if model_params[:top_p]
          model_params
        end

        def default_options(dialect)
          { model: "command-r-plus" }
        end

        def provider_id
          AiApiAuditLog::Provider::Cohere
        end

        private

        def model_uri
          URI(llm_model.url)
        end

        def prepare_payload(prompt, model_params, dialect)
          payload = default_options(dialect).merge(model_params).merge(prompt)
          if prompt[:tools].present?
            payload[:tools] = prompt[:tools]
            payload[:force_single_step] = false
          end
          payload[:tool_results] = prompt[:tool_results] if prompt[:tool_results].present?
          payload[:stream] = true if @streaming_mode

          payload
        end

        def prepare_request(payload)
          headers = {
            "Content-Type" => "application/json",
            "Authorization" => "Bearer #{llm_model.api_key}",
          }

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def extract_completion_from(response_raw)
          parsed = JSON.parse(response_raw, symbolize_names: true)

          if @streaming_mode
            if parsed[:event_type] == "text-generation"
              parsed[:text]
            elsif parsed[:event_type] == "tool-calls-generation"
              # could just be random thinking...
              if parsed.dig(:tool_calls).present?
                @has_tool = true
                parsed.dig(:tool_calls).to_json
              else
                ""
              end
            else
              if parsed[:event_type] == "stream-end"
                @input_tokens = parsed.dig(:response, :meta, :billed_units, :input_tokens)
                @output_tokens = parsed.dig(:response, :meta, :billed_units, :output_tokens)
              end
              nil
            end
          else
            @input_tokens = parsed.dig(:meta, :billed_units, :input_tokens)
            @output_tokens = parsed.dig(:meta, :billed_units, :output_tokens)
            parsed[:text].to_s
          end
        end

        def has_tool?(_ignored)
          @has_tool
        end

        def native_tool_support?
          true
        end

        def add_to_function_buffer(function_buffer, partial: nil, payload: nil)
          if partial
            tools = JSON.parse(partial)
            tools.each do |tool|
              name = tool["name"]
              parameters = tool["parameters"]
              xml_params = parameters.map { |k, v| "<#{k}>#{v}</#{k}>\n" }.join

              current_function = function_buffer.at("invoke")
              if current_function.nil? || current_function.at("tool_name").content.present?
                current_function =
                  function_buffer.at("function_calls").add_child(
                    Nokogiri::HTML5::DocumentFragment.parse(noop_function_call_text + "\n"),
                  )
              end

              current_function.at("tool_name").content = name == "search_local" ? "search" : name
              current_function.at("parameters").children =
                Nokogiri::HTML5::DocumentFragment.parse(xml_params)
            end
          end
          function_buffer
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
      end
    end
  end
end
