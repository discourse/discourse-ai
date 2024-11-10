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
          &blk
        )
          if dialect.respond_to?(:is_gpt_o?) && dialect.is_gpt_o? && block_given?
            # we need to disable streaming and simulate it
            blk.call "", lambda { |*| }
            response = super(dialect, user, model_params, feature_name: feature_name, &nil)
            blk.call response, lambda { |*| }
          else
            super
          end
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
          if dialect.tools.present?
            payload[:tools] = dialect.tools
            if dialect.tool_choice.present?
              payload[:tool_choice] = { type: "function", function: { name: dialect.tool_choice } }
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
        end

        class OpenAiMessageProcessor
          attr_reader :prompt_tokens, :completion_tokens

          def initialize
            @tool = nil
            @tool_arguments = +""
            @prompt_tokens = nil
            @completion_tokens = nil
          end

          def process_message(json)
            result = []
            tool_calls = json.dig(:choices, 0, :message, :tool_calls)

            message = json.dig(:choices, 0, :message, :content)
            result << message if message.present?

            if tool_calls.present?
              tool_calls.each do |tool_call|
                id = tool_call.dig(:id)
                name = tool_call.dig(:function, :name)
                arguments = tool_call.dig(:function, :arguments)
                parameters = arguments.present? ? JSON.parse(arguments, symbolize_names: true) : {}
                result << ToolCall.new(id: id, name: name, parameters: parameters)
              end
            end

            update_usage(json)

            result
          end

          def process_streamed_message(json)
            rval = nil

            tool_calls = json.dig(:choices, 0, :delta, :tool_calls)
            content = json.dig(:choices, 0, :delta, :content)

            finished_tools = json.dig(:choices, 0, :finish_reason) || tool_calls == []

            if tool_calls.present?
              id = tool_calls.dig(0, :id)
              name = tool_calls.dig(0, :function, :name)
              arguments = tool_calls.dig(0, :function, :arguments)

              # TODO: multiple tool support may require index
              #index = tool_calls[0].dig(:index)

              if id.present? && @tool && @tool.id != id
                process_arguments
                rval = @tool
                @tool = nil
              end

              if id.present? && name.present?
                @tool_arguments = +""
                @tool = ToolCall.new(id: id, name: name)
              end

              @tool_arguments << arguments.to_s
            elsif finished_tools && @tool
              parsed_args = JSON.parse(@tool_arguments, symbolize_names: true)
              @tool.parameters = parsed_args
              rval = @tool
              @tool = nil
            elsif content.present?
              rval = content
            end

            update_usage(json)

            rval
          end

          def finish
            rval = []
            if @tool
              process_arguments
              rval << @tool
              @tool = nil
            end

            rval
          end

          private

          def process_arguments
            if @tool_arguments.present?
              parsed_args = JSON.parse(@tool_arguments, symbolize_names: true)
              @tool.parameters = parsed_args
              @tool_arguments = nil
            end
          end

          def update_usage(json)
            @prompt_tokens ||= json.dig(:usage, :prompt_tokens)
            @completion_tokens ||= json.dig(:usage, :completion_tokens)
          end
        end

        def decode(response_raw)
          processor.process_message(JSON.parse(response_raw, symbolize_names: true))
        end

        def decode_chunk(chunk)
          @decoder ||= JsonStreamDecoder.new
          (@decoder << chunk)
            .map { |parsed_json| processor.process_streamed_message(parsed_json) }
            .flatten
            .compact
        end

        def decode_chunk_finish
          @processor.finish
        end

        def xml_tools_enabled?
          false
        end

        private

        def processor
          @processor ||= OpenAiMessageProcessor.new
        end
      end
    end
  end
end
