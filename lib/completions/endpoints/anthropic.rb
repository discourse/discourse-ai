# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Anthropic < Base
        def self.can_contact?(model_provider)
          model_provider == "anthropic"
        end

        def normalize_model_params(model_params)
          # max_tokens, temperature, stop_sequences are already supported
          model_params
        end

        def default_options(dialect)
          mapped_model =
            case llm_model.name
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
              "claude-3-5-sonnet-latest"
            else
              llm_model.name
            end

          # Note: Anthropic requires this param
          max_tokens = 4096
          max_tokens = 8192 if mapped_model.match?(/3.5/)

          options = { model: mapped_model, max_tokens: max_tokens }

          if llm_model.lookup_custom_param("enable_reasoning")
            reasoning_tokens =
              llm_model.lookup_custom_param("reasoning_tokens").to_i.clamp(100, 65_536)

            # this allows for lots of tokens beyond reasoning
            options[:max_tokens] = reasoning_tokens + 30_000
            options[:thinking] = { type: "enabled", budget_tokens: reasoning_tokens }
          end

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
          URI(llm_model.url)
        end

        def xml_tools_enabled?
          !@native_tool_support
        end

        def prepare_payload(prompt, model_params, dialect)
          @native_tool_support = dialect.native_tool_support?

          payload = default_options(dialect).merge(model_params).merge(messages: prompt.messages)

          payload[:system] = prompt.system_prompt if prompt.system_prompt.present?
          payload[:stream] = true if @streaming_mode
          if prompt.has_tools?
            payload[:tools] = prompt.tools
            if dialect.tool_choice.present?
              payload[:tool_choice] = { type: "tool", name: dialect.tool_choice }
            end
          end

          payload
        end

        def prepare_request(payload)
          headers = {
            "anthropic-version" => "2023-06-01",
            "x-api-key" => llm_model.api_key,
            "content-type" => "application/json",
          }

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def decode_chunk(partial_data)
          @decoder ||= JsonStreamDecoder.new
          (@decoder << partial_data)
            .map { |parsed_json| processor.process_streamed_message(parsed_json) }
            .compact
        end

        def decode(response_data)
          processor.process_message(response_data)
        end

        def processor
          @processor ||=
            DiscourseAi::Completions::AnthropicMessageProcessor.new(
              streaming_mode: @streaming_mode,
              partial_tool_calls: partial_tool_calls,
            )
        end

        def has_tool?(_response_data)
          processor.tool_calls.present?
        end

        def tool_calls
          processor.to_tool_calls
        end

        def final_log_update(log)
          log.request_tokens = processor.input_tokens if processor.input_tokens
          log.response_tokens = processor.output_tokens if processor.output_tokens
        end
      end
    end
  end
end
