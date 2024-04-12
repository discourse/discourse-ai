# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module VectorRepresentations
      class TextEmbeddingAda002 < Base
        class << self
          def name
            "text-embedding-ada-002"
          end

          def correctly_configured?
            SiteSetting.ai_openai_api_key.present?
          end

          def dependant_setting_names
            %w[ai_openai_api_key]
          end
        end

        def id
          2
        end

        def version
          1
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
          "halfvec_cosine_ops"
        end

        def vector_from(text, asymetric: false)
          response = DiscourseAi::Inference::OpenAiEmbeddings.perform!(text, model: self.class.name)
          response[:data].first[:embedding]
        end

        def tokenizer
          DiscourseAi::Tokenizer::OpenAiTokenizer
        end
      end
    end
  end
end
