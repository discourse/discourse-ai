# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class Mixtral < Dialect
        class << self
          def can_translate?(model_name)
            %w[mistralai/Mixtral-8x7B-Instruct-v0.1 mistralai/Mistral-7B-Instruct-v0.2].include?(
              model_name,
            )
          end

          def tokenizer
            DiscourseAi::Tokenizer::MixtralTokenizer
          end
        end

        def translate
          messages = prompt.messages

          mixtral_prompt =
            trim_messages(messages).reduce(+"") do |memo, msg|
              next(memo) if msg[:type] == :tool_call

              if msg[:type] == :system
                memo << (<<~TEXT).strip
                <s> [INST]
                #{msg[:content]}
                #{build_tools_prompt}
                [/INST] Ok </s>
                TEXT
              elsif msg[:type] == :model
                memo << "\n#{msg[:content]}</s>"
              elsif msg[:type] == :tool
                memo << "\n"

                memo << (<<~TEXT).strip
                <function_results>
                <result>
                <tool_name>#{msg[:id]}</tool_name>
                <json>
                #{msg[:content]}
                </json>
                </result>
                </function_results>
                TEXT
              else
                memo << "\n[INST]#{msg[:content]}[/INST]"
              end

              memo
            end

          mixtral_prompt << "\n" if mixtral_prompt.ends_with?("[/INST]")

          mixtral_prompt
        end

        def max_prompt_tokens
          32_000
        end
      end
    end
  end
end
