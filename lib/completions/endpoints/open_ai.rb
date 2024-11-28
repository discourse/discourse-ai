# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class OpenAi < Base
        def self.can_contact?(model_provider)
          %w[open_ai azure].include?(model_provider)
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
          { model: llm_model.name }
        end

        def provider_id
          AiApiAuditLog::Provider::OpenAI
        end

        def perform_completion!(
          dialect,
          user,
          model_params = {},
          feature_name: nil,
          feature_context: nil,
          partial_tool_calls: false,
          &blk
        )
          @disable_native_tools = dialect.disable_native_tools?
          super
        end

        private

        def model_uri
          if llm_model.url.to_s.starts_with?("srv://")
            service = DiscourseAi::Utils::DnsSrv.lookup(llm_model.url.sub("srv://", ""))
            api_endpoint = "https://#{service.target}:#{service.port}/v1/chat/completions"
          else
            api_endpoint = llm_model.url
          end

          @uri ||= URI(api_endpoint)
        end

        def prepare_payload(prompt, model_params, dialect)
          payload = default_options.merge(model_params).merge(messages: prompt)

          if @streaming_mode
            payload[:stream] = true

            # Usage is not available in Azure yet.
            # We'll fallback to guess this using the tokenizer.
            payload[:stream_options] = { include_usage: true } if llm_model.provider == "open_ai"
          end
          if !xml_tools_enabled?
            if dialect.tools.present?
              payload[:tools] = dialect.tools
              if dialect.tool_choice.present?
                payload[:tool_choice] = {
                  type: "function",
                  function: {
                    name: dialect.tool_choice,
                  },
                }
              end
            end
          end
          payload
        end

        def prepare_request(payload)
          headers = { "Content-Type" => "application/json" }
          api_key = llm_model.api_key

          if llm_model.provider == "azure"
            headers["api-key"] = api_key
          else
            headers["Authorization"] = "Bearer #{api_key}"
            org_id = llm_model.lookup_custom_param("organization")
            headers["OpenAI-Organization"] = org_id if org_id.present?
          end

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def final_log_update(log)
          log.request_tokens = processor.prompt_tokens if processor.prompt_tokens
          log.response_tokens = processor.completion_tokens if processor.completion_tokens
          log.cached_tokens = processor.cached_tokens if processor.cached_tokens
        end

        def decode(response_raw)
          processor.process_message(JSON.parse(response_raw, symbolize_names: true))
        end

        def decode_chunk(chunk)
          @decoder ||= JsonStreamDecoder.new
          elements =
            (@decoder << chunk)
              .map { |parsed_json| processor.process_streamed_message(parsed_json) }
              .flatten
              .compact

          # Remove duplicate partial tool calls
          # sometimes we stream weird chunks
          seen_tools = Set.new
          elements.select { |item| !item.is_a?(ToolCall) || seen_tools.add?(item) }
        end

        def decode_chunk_finish
          @processor.finish
        end

        def xml_tools_enabled?
          !!@disable_native_tools
        end

        private

        def processor
          @processor ||= OpenAiMessageProcessor.new(partial_tool_calls: partial_tool_calls)
        end
      end
    end
  end
end
