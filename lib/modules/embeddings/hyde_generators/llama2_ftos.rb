# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module HydeGenerators
      class Llama2Ftos < DiscourseAi::Embeddings::HydeGenerators::Llama2
        def prompt(search_term)
          <<~TEXT
              ### System:
              You are a helpful bot
              You create forum posts about a given subject
              
              ### User:
              #{basic_prompt_instruction}
              #{search_term}
    
              ### Assistant:
              Here is a forum post about the above subject:
            TEXT
        end

        def models
          %w[StableBeluga2 Upstage-Llama-2-*-instruct-v2]
        end
      end
    end
  end
end
