# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class Nova < Dialect
        class << self
          def can_translate?(llm_model)
            return llm_model.provider == "aws_bedrock" && llm_model.name.include?("amazon.nova")
          end
        end

        class NovaPrompt
          attr_reader :system, :messages, :inference_config, :tool_config

          def initialize(system, messages, inference_config = nil, tool_config = nil)
            @system = system
            @messages = messages
            @inference_config = inference_config
            @tool_config = tool_config
          end

          def system_prompt
            # small hack for size estimation
            system.to_s
          end

          def has_tools?
            tool_config.present?
          end

          def to_payload(options = nil)
            stop_sequences = options[:stop_sequences]
            max_tokens = options[:max_tokens]

            inference_config =
              options&.slice(:temperature, :top_p, :top_k)

            if stop_sequences.present?
              inference_config[:stopSequences] = stop_sequences
            end

            if max_tokens.present?
              inference_config[:max_new_tokens] = max_tokens
            end

            result = { system: system, messages: messages }
            result[:inferenceConfig] = inference_config if inference_config.present?
            result[:toolConfig] = tool_config if tool_config.present?

            result
          end
        end

        def translate
          messages = super

          # Extract system message if present
          system = messages.shift[:content] if messages.first&.dig(:role) == "system"

          # Convert messages to Nova format
          nova_messages = messages.map { |msg| { role: msg[:role], content: build_content(msg) } }

          # Build inference config if specified in options
          inference_config = build_inference_config

          # Build tool config if tools are present
          tool_config = build_tool_config if prompt.tools.present?

          NovaPrompt.new(
            system.presence && [{ text: system }],
            nova_messages,
            inference_config,
            tool_config,
          )
        end

        def max_prompt_tokens
          llm_model.max_prompt_tokens
        end

        private

        def build_content(msg)
          content = []

          # Add text content
          content << { text: msg[:content] } if msg[:content].present?

          # Add images if present
          msg[:images]&.each { |image| content << image }

          content
        end

        def build_inference_config
          return unless opts[:inference_config]

          config = {}
          ic = opts[:inference_config]

          config[:max_new_tokens] = ic[:max_new_tokens] if ic[:max_new_tokens]
          config[:temperature] = ic[:temperature] if ic[:temperature]
          config[:top_p] = ic[:top_p] if ic[:top_p]
          config[:top_k] = ic[:top_k] if ic[:top_k]
          config[:stopSequences] = ic[:stop_sequences] if ic[:stop_sequences]

          config.present? ? config : nil
        end

        def build_tool_config
          return if !native_tool_support?
          return if !prompt.tools.present?

          {
            tools:
              prompt.tools.map do |tool|
                {
                  toolSpec: {
                    name: tool[:name],
                    description: tool[:description],
                    inputSchema: {
                      json: tool[:input_schema],
                    },
                  },
                }
              end,
            toolChoice: {
              auto: {
              },
            },
          }
        end

        def detect_format(mime_type)
          case mime_type
          when "image/jpeg"
            "jpeg"
          when "image/png"
            "png"
          when "image/gif"
            "gif"
          when "image/webp"
            "webp"
          else
            "jpeg" # default
          end
        end

        def system_msg(msg)
          msg = { role: "system", content: msg[:content] }

          if tools_dialect.instructions.present?
            msg[:content] = msg[:content].dup << "\n\n#{tools_dialect.instructions}"
          end

          msg
        end

        def user_msg(msg)
          images = nil
          if vision_support?
            encoded_uploads = prompt.encoded_uploads(msg)
            encoded_uploads&.each do |upload|
              images ||= []
              images << {
                image: {
                  format: upload[:format] || detect_format(upload[:mime_type]),
                  source: {
                    bytes: upload[:base64],
                  },
                },
              }
            end
          end

          { role: "user", content: msg[:content], images: images }
        end

        def model_msg(msg)
          { role: "assistant", content: msg[:content] }
        end

        def tool_msg(msg)
          translated = tools_dialect.from_raw_tool(msg)
          { role: "user", content: translated }
        end

        def tool_call_msg(msg)
          translated = tools_dialect.from_raw_tool_call(msg)
          { role: "assistant", content: translated }
        end
      end
    end
  end
end
