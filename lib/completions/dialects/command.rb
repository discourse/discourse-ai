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
          messages = prompt.messages

          # ChatGPT doesn't use an assistant msg to improve long-context responses.
          if messages.last[:type] == :model
            messages = messages.dup
            messages.pop
          end

          trimmed_messages = trim_messages(messages)

          chat_history = []
          system_message = nil

          prompt = {}

          trimmed_messages.each do |msg|
            case msg[:type]
            when :system
              if system_message
                chat_history << { role: "SYSTEM", message: msg[:content] }
              else
                system_message = msg[:content]
              end
            when :model
              chat_history << { role: "CHATBOT", message: msg[:content] }
            when :tool_call
              chat_history << { role: "CHATBOT", message: tool_call_to_xml(msg) }
            when :tool
              chat_history << { role: "USER", message: tool_result_to_xml(msg) }
            when :user
              user_message = { role: "USER", message: msg[:content] }
              user_message[:message] = "#{msg[:id]}: #{msg[:content]}" if msg[:id]
              chat_history << user_message
            end
          end

          tools_prompt = build_tools_prompt
          prompt[:preamble] = +"#{system_message}"
          if tools_prompt.present?
            prompt[:preamble] << "\n#{tools_prompt}"
            prompt[
              :preamble
            ] << "\nNEVER attempt to run tools using JSON, always use XML. Lives depend on it."
          end

          prompt[:chat_history] = chat_history if chat_history.present?

          chat_history.reverse_each do |msg|
            if msg[:role] == "USER"
              prompt[:message] = msg[:message]
              chat_history.delete(msg)
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
      end
    end
  end
end
