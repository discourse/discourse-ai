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
            if msg[:type] == :system
              if system_message
                chat_history << { role: "SYSTEM", message: msg[:content] }
              else
                system_message = msg
              end
            elsif msg[:type] == :model
              chat_history << { role: "CHATBOT", message: msg[:content] }
            elsif msg[:type] == :tool_call
              call_details = JSON.parse(msg[:content], symbolize_names: true)
              call_details[:arguments] = call_details[:arguments].to_json
              call_details[:name] = msg[:name]

              {
                role: "assistant",
                content: nil,
                tool_calls: [{ type: "function", function: call_details, id: msg[:id] }],
              }
            elsif msg[:type] == :tool
              { role: "tool", tool_call_id: msg[:id], content: msg[:content], name: msg[:name] }
            else
              user_message = { role: "USER", message: msg[:content] }
              user_message[:message] = "#{msg[:id]}: #{msg[:content]}" if msg[:id]
              chat_history << user_message
            end
          end

          prompt[:preamble] = system_message[:content] if system_message

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

        def tools
          prompt.tools.map do |t|
            tool = {}

            tool[:name] = t[:name]
            tool[:description] = t[:description]

            params = {}
            t[:parameters].each do |param|
              params[param[:name]] = {
                required: param[:required],
                description: param[:description],
                type: python_type(param[:type], param[:item_type]),
              }
            end

            tool[:parameter_definitions] = params

            tool
          end
        end

        def python_type(type, item_type = nil)
          return "#{python_type(item_type)}[]" if item_type && type == "array"

          case type
          when "string"
            "str"
          when "integer"
            "int"
          when "float"
            "float"
          when "boolean"
            "bool"
          when "list"
            "list"
          when "dictionary"
            "dict"
          else
            "str"
          end
        end

        def max_prompt_tokens
          # provide a buffer of 120 tokens - our function counting is not
          # 100% accurate and getting numbers to align exactly is very hard
          buffer = (opts[:max_tokens] || 2500) + 50

          if tools.present?
            # note this is about 100 tokens over, OpenAI have a more optimal representation
            @function_size ||= self.class.tokenizer.size(tools.to_json.to_s)
            buffer += @function_size
          end

          model_max_tokens - buffer
        end

        private

        def per_message_overhead
          # open ai defines about 4 tokens per message of overhead
          4
        end

        def calculate_message_token(context)
          self.class.tokenizer.size(context[:content].to_s + context[:name].to_s)
        end

        def model_max_tokens
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
      end
    end
  end
end
