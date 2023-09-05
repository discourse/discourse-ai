# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module HydeGenerators
      class Llama2 < DiscourseAi::Embeddings::HydeGenerators::Base
        def prompt(search_term)
          <<~TEXT
              [INST] <<SYS>>
              You are a helpful bot
              You create forum posts about a given topic
              <</SYS>>

              Topic: #{search_term}
              [/INST]
              Here is a forum post about the above topic:
            TEXT
        end

        def models
          ["Llama2-*-chat-hf"]
        end

        def hypothetical_post_from(query)
          ::DiscourseAi::Inference::HuggingFaceTextGeneration.perform!(
            prompt(query),
            SiteSetting.ai_embeddings_semantic_search_hyde_model,
            token_limit: 400,
          ).dig(:generated_text)
        end
      end
    end
  end
end
