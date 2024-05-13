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
          messages = super

          system_prompt = messages.shift[:content] if messages.first[:role] == "system"

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
          return opts[:max_prompt_tokens] if opts.dig(:max_prompt_tokens).present?
          # Longer term it will have over 1 million
          200_000 # Claude-3 has a 200k context window for now
        end

        private

        def model_msg(msg)
          { role: "assistant", content: msg[:content] }
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
          content << msg[:content]
          content = inline_images(content, msg)

          { role: "user", content: content }
        end

        def inline_images(content, message)
          if model_name.include?("claude-3")
            encoded_uploads = prompt.encoded_uploads(message)
            if encoded_uploads.present?
              new_content = []
              new_content.concat(
                encoded_uploads.map do |details|
                  {
                    source: {
                      type: "base64",
                      data: details[:base64],
                      media_type: details[:mime_type],
                    },
                    type: "image",
                  }
                end,
              )
              new_content << { type: "text", text: content }
              content = new_content
            end
          end

          content
        end
      end
    end
  end
end
