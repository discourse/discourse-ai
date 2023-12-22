# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class Mixtral < Dialect
        class << self
          def can_translate?(model_name)
            %w[mistralai/Mixtral-8x7B-Instruct-v0.1 mistralai/Mistral-7B-Instruct-v0.2].include?(model_name)
          end

          def tokenizer
            DiscourseAi::Tokenizer::MixtralTokenizer
          end
        end

        def translate
          mixtral_prompt = +<<~TEXT
          <s> [INST]
          #{prompt[:insts]}
          #{build_tools_prompt}#{prompt[:post_insts]}
          [/INST] Ok </s>
          TEXT

          if prompt[:examples]
            prompt[:examples].each do |example_pair|
              mixtral_prompt << "[INST] #{example_pair.first} [/INST]\n"
              mixtral_prompt << "#{example_pair.second}\n"
            end
          end

          mixtral_prompt << conversation_context if prompt[:conversation_context].present?

          mixtral_prompt << "[INST] #{prompt[:input]} [/INST]\n"
        end

        def conversation_context
          return "" if prompt[:conversation_context].blank?

          trimmed_context = trim_context(prompt[:conversation_context])

          trimmed_context
            .reverse
            .reduce(+"") do |memo, context|
              memo << "[INST] " if context[:type] == "user"

              if context[:type] == "tool"
                memo << <<~TEXT

                <function_results>
                <result>
                <tool_name>#{context[:name]}</tool_name>
                <json>
                #{context[:content]}
                </json>
                </result>
                </function_results>
                TEXT
              else
                memo << " " << context[:content] << "\n"
                memo << " [/INST]" if context[:type] == "user"
              end

              memo
            end
        end

        def max_prompt_tokens
          32_000
        end
      end
    end
  end
end
