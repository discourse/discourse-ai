# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class Claude < Dialect
        class << self
          def can_translate?(llm_model)
            llm_model.provider == "anthropic" ||
              (llm_model.provider == "aws_bedrock") &&
                (llm_model.name.include?("anthropic") || llm_model.name.include?("claude"))
          end
        end

        class ClaudePrompt
          attr_reader :system_prompt
          attr_reader :messages
          attr_reader :tools

          def initialize(system_prompt, messages, tools)
            @system_prompt = system_prompt
            @messages = messages
            @tools = tools
          end

          def has_tools?
            tools.present?
          end
        end

        def translate
          messages = super

          system_prompt = messages.shift[:content] if messages.first[:role] == "system"

          if !system_prompt && !native_tool_support?
            system_prompt = tools_dialect.instructions.presence
          end

          interleving_messages = []
          previous_message = nil

          messages.each do |message|
            if previous_message
              if previous_message[:role] == "user" && message[:role] == "user"
                interleving_messages << { role: "assistant", content: "OK" }
              elsif previous_message[:role] == "assistant" && message[:role] == "assistant"
                interleving_messages << { role: "user", content: "OK" }
              end
            end
            interleving_messages << message
            previous_message = message
          end

          tools = nil
          tools = tools_dialect.translated_tools if native_tool_support?

          ClaudePrompt.new(system_prompt.presence, interleving_messages, tools)
        end

        def max_prompt_tokens
          llm_model.max_prompt_tokens
        end

        def native_tool_support?
          !llm_model.lookup_custom_param("disable_native_tools")
        end

        private

        def tools_dialect
          if native_tool_support?
            @tools_dialect ||= DiscourseAi::Completions::Dialects::ClaudeTools.new(prompt.tools)
          else
            super
          end
        end

        def tool_call_msg(msg)
          translated = tools_dialect.from_raw_tool_call(msg)
          { role: "assistant", content: translated }
        end

        def tool_msg(msg)
          translated = tools_dialect.from_raw_tool(msg)
          { role: "user", content: translated }
        end

        def model_msg(msg)
          if msg[:thinking] || msg[:redacted_thinking_signature]
            content_array = []

            if msg[:thinking]
              content_array << {
                type: "thinking",
                thinking: msg[:thinking],
                signature: msg[:thinking_signature],
              }
            end

            if msg[:redacted_thinking_signature]
              content_array << {
                type: "redacted_thinking",
                data: msg[:redacted_thinking_signature],
              }
            end

            content_array << { type: "text", text: msg[:content] }

            { role: "assistant", content: content_array }
          else
            { role: "assistant", content: msg[:content] }
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
          content = +""
          content << "#{msg[:id]}: " if msg[:id]
          message_content = msg[:content]
          message_content = [message_content] if !message_content.is_a?(Array)

          content_array = []

          message_content.each do |content_part|
            if content_part.is_a?(String)
              content << content_part
            elsif content_part.is_a?(Hash) && vision_support?
              content_array << { type: "text", text: content } if content.present?
              image = image_node(content_part[:upload_id])
              content_array << image if image
              content = +""
            end
          end

          content_array << { type: "text", text: content } if content.present?

          { role: "user", content: content_array }
        end

        def image_node(upload_id)
          details = prompt.encode_upload(upload_id)
          return nil if details.blank?
          {
            source: {
              type: "base64",
              data: details[:base64],
              media_type: details[:mime_type],
            },
            type: "image",
          }
        end
      end
    end
  end
end
