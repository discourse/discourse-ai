# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class Claude < Dialect
        class << self
          def can_translate?(model_name)
            %w[claude-instant-1 claude-2].include?(model_name)
          end

          def tokenizer
            DiscourseAi::Tokenizer::AnthropicTokenizer
          end
        end

        def translate
          messages = prompt.messages

          trimmed_messages = trim_messages(messages)

          # Need to include this differently
          last_message = trimmed_messages.last[:type] == :assistant ? trimmed_messages.pop : nil

          claude_prompt =
            trimmed_messages.reduce(+"") do |memo, msg|
              if msg[:type] == :tool_call
                memo << "\n\nAssistant: #{tool_call_to_xml(msg)}"
              elsif msg[:type] == :system
                memo << "Human: " unless uses_system_message?
                memo << msg[:content]
                if prompt.tools.present?
                  memo << "\n"
                  memo << build_tools_prompt
                end
              elsif msg[:type] == :model
                memo << "\n\nAssistant: #{msg[:content]}"
              elsif msg[:type] == :tool
                memo << "\n\nHuman:\n"
                memo << tool_result_to_xml(msg)
              else
                memo << "\n\nHuman: "
                memo << "#{msg[:id]}: " if msg[:id]
                memo << msg[:content]
              end

              memo
            end

          claude_prompt << "\n\nAssistant:"
          claude_prompt << " #{last_message[:content]}:" if last_message

          claude_prompt
        end

        def max_prompt_tokens
          100_000 # Claude-2.1 has a 200k context window.
        end

        private

        def uses_system_message?
          model_name == "claude-2"
        end
      end
    end
  end
end
