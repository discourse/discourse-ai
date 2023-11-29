# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class ChatGPT
        def self.can_translate?(model_name)
          %w[gpt-3.5-turbo gpt-4 gpt-3.5-turbo-16k gpt-4-32k].include?(model_name)
        end

        def translate(generic_prompt)
          open_ai_prompt = [
            {
              role: "system",
              content: [generic_prompt[:insts], generic_prompt[:post_insts].to_s].join("\n"),
            },
          ]

          if generic_prompt[:examples]
            generic_prompt[:examples].each do |example_pair|
              open_ai_prompt << { role: "user", content: example_pair.first }
              open_ai_prompt << { role: "assistant", content: example_pair.second }
            end
          end

          open_ai_prompt << { role: "user", content: generic_prompt[:input] }
        end

        def tokenizer
          DiscourseAi::Tokenizer::OpenAiTokenizer
        end
      end
    end
  end
end
