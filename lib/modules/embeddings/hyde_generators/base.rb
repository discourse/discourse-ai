# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module HydeGenerators
      class Base
        def self.current_hyde_model
          DiscourseAi::Embeddings::HydeGenerators::Base.descendants.find do |generator_klass|
            generator_klass.new.models.include?(
              SiteSetting.ai_embeddings_semantic_search_hyde_model,
            )
          end
        end

        def basic_prompt_instruction
          <<~TEXT
            Act as a content writer for a forum.
            The forum description is as follows:
            #{SiteSetting.title}
            #{SiteSetting.site_description}

            Given the forum description write a forum post about the following subject:
          TEXT
        end
      end
    end
  end
end
