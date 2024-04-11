# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class Llama2Classic < Dialect
        class << self
          def can_translate?(model_name)
            %w[Llama2-*-chat-hf Llama2-chat-hf].include?(model_name)
          end

          def tokenizer
            DiscourseAi::Tokenizer::Llama2Tokenizer
          end
        end

        def translate
          messages = prompt.messages

          llama2_prompt =
            trim_messages(messages).reduce(+"") do |memo, msg|
              next(memo) if msg[:type] == :tool_call

              if msg[:type] == :system
                memo << (<<~TEXT).strip
                [INST]
                <<SYS>>
                #{msg[:content]}
                #{build_tools_prompt}
                <</SYS>>
                [/INST]
                TEXT
              elsif msg[:type] == :model
                memo << "\n#{msg[:content]}"
              elsif msg[:type] == :tool
                JSON.parse(msg[:content], symbolize_names: true)
                memo << "\n[INST]\n"

                memo << (<<~TEXT).strip
                <function_results>
                <result>
                <tool_name>#{msg[:id]}</tool_name>
                <json>
                #{msg[:content]}
                </json>
                </result>
                </function_results>
                [/INST]
                TEXT
              else
                memo << "\n[INST]#{msg[:content]}[/INST]"
              end

              memo
            end

          llama2_prompt << "\n" if llama2_prompt.ends_with?("[/INST]")

          llama2_prompt
        end

        def max_prompt_tokens
          SiteSetting.ai_hugging_face_token_limit
        end
      end
    end
  end
end
