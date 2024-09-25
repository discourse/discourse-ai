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

        # TODO: Add tool suppport

        def max_prompt_tokens
          llm_model.max_prompt_tokens
        end

        private

        def tokenizer
          llm_model.tokenizer_class
        end

        def model_msg(msg)
          { role: "assistant", content: msg[:content] }
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
