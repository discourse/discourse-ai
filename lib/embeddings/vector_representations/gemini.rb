# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module VectorRepresentations
      class Gemini < Base
        class << self
          def name
            "gemini"
          end

          def correctly_configured?
            SiteSetting.ai_gemini_api_key.present?
          end

          def dependant_setting_names
            %w[ai_gemini_api_key]
          end
        end

        def id
          5
        end

        def version
          1
        end

        def dimensions
          768
        end

        def max_sequence_length
          1536 # Gemini has a max sequence length of 2048, but the API has a limit of 10000 bytes, hence the lower value
        end

        def pg_function
          "<=>"
        end

        def pg_index_type
          "vector_cosine_ops"
        end

        def vector_from(text)
          response = DiscourseAi::Inference::GeminiEmbeddings.perform!(text)
          response[:embedding][:values]
        end

        # There is no public tokenizer for Gemini, and from the ones we already ship in the plugin
        # OpenAI gets the closest results. Gemini Tokenizer results in ~10% less tokens, so it's safe
        # to use OpenAI tokenizer since it will overestimate the number of tokens.
        def tokenizer
          DiscourseAi::Tokenizer::OpenAiTokenizer
        end
      end
    end
  end
end
