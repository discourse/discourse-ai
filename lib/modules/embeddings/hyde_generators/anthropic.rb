# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module HydeGenerators
      class Anthropic < DiscourseAi::Embeddings::HydeGenerators::Base
        def prompt(search_term)
          <<~TEXT
              Given a search term given between <input> tags, generate a forum post about a given subject.
              #{basic_prompt_instruction}
              <input>#{search_term}</input>

              Respond with the generated post between <ai> tags.
            TEXT
        end

        def models
          %w[claude-instant-1 claude-2]
        end

        def hypothetical_post_from(query)
          response =
            ::DiscourseAi::Inference::AnthropicCompletions.perform!(
              prompt(query),
              SiteSetting.ai_embeddings_semantic_search_hyde_model,
              max_tokens: 400,
            ).dig(:completion)

          Nokogiri::HTML5.fragment(response).at("ai").text
        end
      end
    end
  end
end
