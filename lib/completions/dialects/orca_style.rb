# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class OrcaStyle
        def self.can_translate?(model_name)
          %w[StableBeluga2 Upstage-Llama-2-*-instruct-v2].include?(model_name)
        end

        def translate(generic_prompt)
          orca_style_prompt =
            +"### System:\n#{[generic_prompt[:insts], generic_prompt[:post_insts].to_s].join("\n")}\n"

          if generic_prompt[:examples]
            generic_prompt[:examples].each do |example_pair|
              orca_style_prompt << "### User:\n#{example_pair.first}\n"
              orca_style_prompt << "### Assistant:\n#{example_pair.second}\n"
            end
          end

          orca_style_prompt << "### User:\n#{generic_prompt[:input]}\n"

          orca_style_prompt << "### Assistant:\n"
        end

        def tokenizer
          DiscourseAi::Tokenizer::Llama2Tokenizer
        end
      end
    end
  end
end
