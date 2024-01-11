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

        def pad_newlines!(prompt)
          if prompt[-1..-1] != "\n"
            prompt << "\n\n"
          elsif prompt[-2..-1] != "\n\n"
            prompt << "\n"
          end
        end

        def translate
          claude_prompt = uses_system_message? ? +"" : +"Human: "
          claude_prompt << prompt[:insts] << "\n"

          claude_prompt << build_tools_prompt if prompt[:tools]

          claude_prompt << build_examples(prompt[:examples]) if prompt[:examples]

          pad_newlines!(claude_prompt)

          claude_prompt << conversation_context if prompt[:conversation_context]

          pad_newlines!(claude_prompt)

          if uses_system_message? && (prompt[:input] || prompt[:post_insts])
            claude_prompt << "Human: "
          end
          claude_prompt << "#{prompt[:input]}\n" if prompt[:input]

          claude_prompt << "#{prompt[:post_insts]}\n" if prompt[:post_insts]

          pad_newlines!(claude_prompt)

          claude_prompt << "Assistant: "
          claude_prompt << " #{prompt[:final_insts]}:" if prompt[:final_insts]
          claude_prompt
        end

        def max_prompt_tokens
          100_000 # Claude-2.1 has a 200k context window.
        end

        def conversation_context
          return "" if prompt[:conversation_context].blank?

          clean_context = prompt[:conversation_context].select { |cc| cc[:type] != "tool_call" }
          flattened_context = flatten_context(clean_context)
          trimmed_context = trim_context(flattened_context)

          trimmed_context
            .reverse
            .map do |context|
              row = context[:type] == "user" ? +"Human:" : +"Assistant:"

              if context[:type] == "tool"
                row << "\n"
                row << (<<~TEXT).strip
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
                row << " "
                row << context[:content]
              end
            end
            .join("\n\n")
        end

        private

        def uses_system_message?
          model_name == "claude-2"
        end

        def build_examples(examples_arr)
          examples_arr.reduce("") do |memo, example|
            memo += "<example>\nH: #{example[0]}\nA: #{example[1]}\n</example>\n"
          end
        end
      end
    end
  end
end
