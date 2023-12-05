# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class Llama2Classic
        def self.can_translate?(model_name)
          %w[Llama2-*-chat-hf Llama2-chat-hf].include?(model_name)
        end

        def translate(generic_prompt)
          llama2_prompt =
            +"[INST]<<SYS>>#{[generic_prompt[:insts], generic_prompt[:post_insts].to_s].join("\n")}<</SYS>>[/INST]\n"

          if generic_prompt[:examples]
            generic_prompt[:examples].each do |example_pair|
              llama2_prompt << "[INST]#{example_pair.first}[/INST]\n"
              llama2_prompt << "#{example_pair.second}\n"
            end
          end

          llama2_prompt << "[INST]#{generic_prompt[:input]}[/INST]\n"
        end

        def tokenizer
          DiscourseAi::Tokenizer::Llama2Tokenizer
        end
      end
    end
  end
end
