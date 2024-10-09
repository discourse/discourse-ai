# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class Ollama < Dialect
        class << self
          def can_translate?(model_provider)
            model_provider == "ollama"
          end
        end

        def native_tool_support?
          llm_model.lookup_custom_param("enable_native_tool")
        end

        def max_prompt_tokens
          llm_model.max_prompt_tokens
        end

        private

        def tools_dialect
          @tools_dialect ||= DiscourseAi::Completions::Dialects::OllamaTools.new(prompt.tools)
        end

        def tokenizer
          llm_model.tokenizer_class
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

        def system_msg(msg)
          { role: "system", content: msg[:content] }
        end

        def user_msg(msg)
          user_message = { role: "user", content: msg[:content] }

          # TODO: Add support for user messages with empbeded user ids
          # TODO: Add support for user messages with attachments

          user_message
        end
      end
    end
  end
end
