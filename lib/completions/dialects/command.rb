# frozen_string_literal: true

# see: https://docs.cohere.com/reference/chat
#
module DiscourseAi
  module Completions
    module Dialects
      class Command < Dialect
        class << self
          def can_translate?(model_name)
            %w[command-light command command-r command-r-plus].include?(model_name)
          end

          def tokenizer
            DiscourseAi::Tokenizer::OpenAiTokenizer
          end
        end

        VALID_ID_REGEX = /\A[a-zA-Z0-9_]+\z/

        def translate
          messages = super

          system_message = messages.shift[:message] if messages.first[:role] == "SYSTEM"

          prompt = { preamble: +"#{system_message}" }
          prompt[:chat_history] = messages if messages.present?

          messages.reverse_each do |msg|
            if msg[:role] == "USER"
              prompt[:message] = msg[:message]
              messages.delete(msg)
              break
            end
          end

          prompt
        end

        def max_prompt_tokens
          case model_name
          when "command-light"
            4096
          when "command"
            8192
          when "command-r"
            131_072
          when "command-r-plus"
            131_072
          else
            8192
          end
        end

        private

        def per_message_overhead
          0
        end

        def calculate_message_token(context)
          self.class.tokenizer.size(context[:content].to_s + context[:name].to_s)
        end

        def tools_dialect
          @tools_dialect ||= DiscourseAi::Completions::Dialects::XmlTools.new(prompt.tools)
        end

        def system_msg(msg)
          cmd_msg = { role: "SYSTEM", message: msg[:content] }

          if tools_dialect.instructions.present?
            cmd_msg[:message] = [
              msg[:content],
              tools_dialect.instructions,
              "NEVER attempt to run tools using JSON, always use XML. Lives depend on it.",
            ].join("\n")
          end

          cmd_msg
        end

        def model_msg(msg)
          { role: "CHATBOT", message: msg[:content] }
        end

        def tool_call_msg(msg)
          { role: "CHATBOT", message: tools_dialect.from_raw_tool_call(msg) }
        end

        def tool_msg(msg)
          { role: "USER", message: tools_dialect.from_raw_tool(msg) }
        end

        def user_msg(msg)
          user_message = { role: "USER", message: msg[:content] }
          user_message[:message] = "#{msg[:id]}: #{msg[:content]}" if msg[:id]

          user_message
        end
      end
    end
  end
end
