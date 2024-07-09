# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Anthropic < Base
        class << self
          def can_contact?(endpoint_name)
            endpoint_name == "anthropic"
          end

          def dependant_setting_names
            %w[ai_anthropic_api_key]
          end

          def correctly_configured?(_model_name)
            SiteSetting.ai_anthropic_api_key.present?
          end

          def endpoint_name(model_name)
            "Anthropic - #{model_name}"
          end
        end

        def normalize_model_params(model_params)
          # max_tokens, temperature, stop_sequences are already supported
          model_params
        end

        def default_options(dialect)
          mapped_model =
            case model
            when "claude-2"
              "claude-2.1"
            when "claude-instant-1"
              "claude-instant-1.2"
            when "claude-3-haiku"
              "claude-3-haiku-20240307"
            when "claude-3-sonnet"
              "claude-3-sonnet-20240229"
            when "claude-3-opus"
              "claude-3-opus-20240229"
            when "claude-3-5-sonnet"
              "claude-3-5-sonnet-20240620"
            else
              model
            end

          options = { model: mapped_model, max_tokens: 3_000 }

          options[:stop_sequences] = ["</function_calls>"] if !dialect.native_tool_support? &&
            dialect.prompt.has_tools?

          options
        end

        def provider_id
          AiApiAuditLog::Provider::Anthropic
        end

        private

        def xml_tags_to_strip(dialect)
          if dialect.prompt.has_tools?
            %w[thinking search_quality_reflection search_quality_score]
          else
            []
          end
        end

        # this is an approximation, we will update it later if request goes through
        def prompt_size(prompt)
          tokenizer.size(prompt.system_prompt.to_s + " " + prompt.messages.to_s)
        end

        def model_uri
          url = llm_model&.url || "https://api.anthropic.com/v1/messages"

          URI(url)
        end

        def prepare_payload(prompt, model_params, dialect)
          @native_tool_support = dialect.native_tool_support?

          payload = default_options(dialect).merge(model_params).merge(messages: prompt.messages)

          payload[:system] = prompt.system_prompt if prompt.system_prompt.present?
          payload[:stream] = true if @streaming_mode
          payload[:tools] = prompt.tools if prompt.has_tools?

          payload
        end

        def prepare_request(payload)
          headers = {
            "anthropic-version" => "2023-06-01",
            "x-api-key" => llm_model&.api_key || SiteSetting.ai_anthropic_api_key,
            "content-type" => "application/json",
          }

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def processor
          @processor ||=
            DiscourseAi::Completions::AnthropicMessageProcessor.new(streaming_mode: @streaming_mode)
        end

        def add_to_function_buffer(function_buffer, partial: nil, payload: nil)
          processor.to_xml_tool_calls(function_buffer) if !partial
        end

        def extract_completion_from(response_raw)
          processor.process_message(response_raw)
        end

        def has_tool?(_response_data)
          processor.tool_calls.present?
        end

        def final_log_update(log)
          log.request_tokens = processor.input_tokens if processor.input_tokens
          log.response_tokens = processor.output_tokens if processor.output_tokens
        end

        def native_tool_support?
          @native_tool_support
        end

        def partials_from(decoded_chunk)
          decoded_chunk.split("\n").map { |line| line.split("data: ", 2)[1] }.compact
        end
      end
    end
  end
end
