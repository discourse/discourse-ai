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
        end

        VALID_ID_REGEX = /\A[a-zA-Z0-9_]+\z/

        def tokenizer
          llm_model&.tokenizer_class || DiscourseAi::Tokenizer::OpenAiTokenizer
        end

        def translate
          messages = super

          system_message = messages.shift[:message] if messages.first[:role] == "SYSTEM"

          prompt = { preamble: +"#{system_message}" }

          if messages.present?
            prompt[:chat_history] = messages

            tool_messages = []
            messages.delete_if do |msg|
              if %i[tool_call tool].include?(msg[:type])
                tool_messages << msg
                true
              end
            end
          end

          messages.reverse_each do |msg|
            if msg[:role] == "USER"
              prompt[:message] = msg[:message]
              messages.delete(msg)
              break
            end
          end

          prompt[:tools] = tools_dialect.translated_tools
          prompt[:tool_results] = tools_dialect.tool_results(tool_messages)

          prompt
        end

        def max_prompt_tokens
          return llm_model.max_prompt_tokens if llm_model&.max_prompt_tokens

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

        def native_tool_support?
          true
        end

        private

        def tools_dialect
          @tools_dialect ||= DiscourseAi::Completions::Dialects::CohereTools.new(prompt.tools)
        end

        def per_message_overhead
          0
        end

        def calculate_message_token(context)
          self.tokenizer.size(context[:content].to_s + context[:name].to_s)
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
          msg
        end

        def tool_msg(msg)
          msg
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
