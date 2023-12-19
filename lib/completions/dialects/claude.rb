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
          claude_prompt = +"Human: #{prompt[:insts]}\n"

          claude_prompt << build_tools_prompt if prompt[:tools]

          claude_prompt << build_examples(prompt[:examples]) if prompt[:examples]

          claude_prompt << conversation_context if prompt[:conversation_context]

          claude_prompt << "#{prompt[:input]}\n"

          claude_prompt << "#{prompt[:post_insts]}\n" if prompt[:post_insts]

          claude_prompt << "Assistant:"
          claude_prompt << " #{prompt[:final_insts]}:" if prompt[:final_insts]
          claude_prompt << "\n"
        end

        def max_prompt_tokens
          50_000
        end

        def conversation_context
          return "" if prompt[:conversation_context].blank?

          trimmed_context = trim_context(prompt[:conversation_context])

          trimmed_context
            .reverse
            .reduce(+"") do |memo, context|
              memo << (context[:type] == "user" ? "Human:" : "Assistant:")

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
              end

              memo
            end
        end

        private

        def build_examples(examples_arr)
          examples_arr.reduce("") do |memo, example|
            memo += "<example>\nH: #{example[0]}\nA: #{example[1]}\n</example>\n"
          end
        end
      end
    end
  end
end
