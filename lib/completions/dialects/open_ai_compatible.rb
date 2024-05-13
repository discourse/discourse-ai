# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class OpenAiCompatible < Dialect
        class << self
          def can_translate?(_model_name)
            true
          end

          def tokenizer
            DiscourseAi::Tokenizer::Llama3Tokenizer
          end
        end

        def tools
          @tools ||= tools_dialect.translated_tools
        end

        def max_prompt_tokens
          return opts[:max_prompt_tokens] if opts.dig(:max_prompt_tokens).present?

          32_000
        end

        private

        def system_msg(msg)
          { role: "system", content: msg[:content] }
        end

        def model_msg(msg)
          { role: "assistant", content: msg[:content] }
        end

        def tool_call_msg(msg)
          tools_dialect.from_raw_tool_call(msg)
        end

        def tool_msg(msg)
          tools_dialect.from_raw_tool(msg)
        end

        def user_msg(msg)
          content = +""
          content << "#{msg[:id]}: " if msg[:id]
          content << msg[:content]

          { role: "user", content: content }
        end
      end
    end
  end
end
