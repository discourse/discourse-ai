# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module Models
      class MultilingualE5Large < Base
        class << self
          def id
            3
          end

          def version
            1
          end

          def name
            "multilingual-e5-large"
          end

          def dimensions
            1024
          end

          def max_sequence_length
            512
          end

          def pg_function
            "<=>"
          end

          def pg_index_type
            "vector_cosine_ops"
          end

          def generate_embeddings(text)
            DiscourseAi::Inference::DiscourseClassifier.perform!(
              "#{SiteSetting.ai_embeddings_discourse_service_api_endpoint}/api/v1/classify",
              name,
              "query: #{text}",
              SiteSetting.ai_embeddings_discourse_service_api_key,
            )
          end

          def tokenizer
            DiscourseAi::Tokenizer::MultilingualE5LargeTokenizer
          end
        end
      end
    end
  end
end
