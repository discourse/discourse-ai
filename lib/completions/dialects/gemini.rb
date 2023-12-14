# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class Gemini
        def self.can_translate?(model_name)
          %w[gemini-pro].include?(model_name)
        end

        def translate(generic_prompt)
          gemini_prompt = [
            {
              role: "user",
              parts: {
                text: [generic_prompt[:insts], generic_prompt[:post_insts].to_s].join("\n"),
              },
            },
            {
              role: "model",
              parts: {
                text: "Ok.",
              },
            },
          ]

          if generic_prompt[:examples]
            generic_prompt[:examples].each do |example_pair|
              gemini_prompt << { role: "user", parts: { text: example_pair.first } }
              gemini_prompt << { role: "model", parts: { text: example_pair.second } }
            end
          end

          gemini_prompt << { role: "user", parts: { text: generic_prompt[:input] } }
        end

        def tokenizer
          DiscourseAi::Tokenizer::OpenAiTokenizer ## TODO Replace with GeminiTokenizer
        end
      end
    end
  end
end
