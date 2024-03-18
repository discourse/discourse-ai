# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class Claude < Dialect
        class << self
          def can_translate?(model_name)
            %w[claude-instant-1 claude-2 claude-3-haiku claude-3-sonnet claude-3-opus].include?(
              model_name,
            )
          end

          def tokenizer
            DiscourseAi::Tokenizer::AnthropicTokenizer
          end
        end

        class ClaudePrompt
          attr_reader :system_prompt
          attr_reader :messages

          def initialize(system_prompt, messages)
            @system_prompt = system_prompt
            @messages = messages
          end
        end

        def translate
          messages = prompt.messages
          system_prompt = +""

          messages =
            trim_messages(messages)
              .map do |msg|
                case msg[:type]
                when :system
                  system_prompt << msg[:content]
                  nil
                when :tool_call
                  { role: "assistant", content: tool_call_to_xml(msg) }
                when :tool
                  { role: "user", content: tool_result_to_xml(msg) }
                when :model
                  { role: "assistant", content: msg[:content] }
                when :user
                  content = +""
                  content << "#{msg[:id]}: " if msg[:id]
                  content << msg[:content]

                  { role: "user", content: content }
                end
              end
              .compact

          if prompt.tools.present?
            system_prompt << "\n\n"
            system_prompt << build_tools_prompt
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

          ClaudePrompt.new(system_prompt.presence, interleving_messages)
        end

        def max_prompt_tokens
          # Longer term it will have over 1 million
          200_000 # Claude-3 has a 200k context window for now
        end
      end
    end
  end
end
