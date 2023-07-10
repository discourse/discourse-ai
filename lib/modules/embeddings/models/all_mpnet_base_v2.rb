# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module Models
      class AllMpnetBaseV2 < Base
        class << self
          def id
            1
          end

          def version
            1
          end

          def name
            "all-mpnet-base-v2"
          end

          def dimensions
            768
          end

          def max_sequence_length
            384
          end

          def pg_function
            "<#>"
          end

          def pg_index_type
            "vector_ip_ops"
          end

          def generate_embeddings(text)
            DiscourseAi::Inference::DiscourseClassifier.perform!(
              "#{SiteSetting.ai_embeddings_discourse_service_api_endpoint}/api/v1/classify",
              name,
              text,
              SiteSetting.ai_embeddings_discourse_service_api_key,
            )
          end

          def tokenizer
            DiscourseAi::Tokenizer::AllMpnetBaseV2Tokenizer
          end
        end
      end
    end
  end
end
