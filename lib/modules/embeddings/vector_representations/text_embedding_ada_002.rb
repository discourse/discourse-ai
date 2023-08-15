# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module VectorRepresentations
      class TextEmbeddingAda002 < Base
        def id
          2
        end

        def version
          1
        end

        def name
          "text-embedding-ada-002"
        end

        def dimensions
          1536
        end

        def max_sequence_length
          8191
        end

        def pg_function
          "<=>"
        end

        def pg_index_type
          "vector_cosine_ops"
        end

        def vector_from(text)
          response = DiscourseAi::Inference::OpenAiEmbeddings.perform!(text)
          response[:data].first[:embedding]
        end

        def tokenizer
          DiscourseAi::Tokenizer::OpenAiTokenizer
        end
      end
    end
  end
end
