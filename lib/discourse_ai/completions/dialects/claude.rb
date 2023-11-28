# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class Claude
        def self.can_translate?(model_name)
          %w[claude-instant-1 claude-2].include?(model_name)
        end

        def translate(generic_prompt)
          claude_prompt = +"Human: #{generic_prompt[:insts]}\n"

          claude_prompt << build_examples(generic_prompt[:examples]) if generic_prompt[:examples]

          claude_prompt << "#{generic_prompt[:input]}\n"

          claude_prompt << "#{generic_prompt[:post_insts]}\n" if generic_prompt[:post_insts]

          claude_prompt << "Assistant:\n"
        end

        def tokenizer
          DiscourseAi::Tokenizer::AnthropicTokenizer
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
