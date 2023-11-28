# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module VectorRepresentations
      class MultilingualE5Large < Base
        def vector_from(text)
          if SiteSetting.ai_hugging_face_tei_endpoint.present?
            DiscourseAi::Inference::HuggingFaceTextEmbeddings
              .perform!(text)
              .first
          elsif SiteSetting.ai_embeddings_discourse_service_api_endpoint.present?
            DiscourseAi::Inference::DiscourseClassifier.perform!(
              "#{SiteSetting.ai_embeddings_discourse_service_api_endpoint}/api/v1/classify",
              name,
              "query: #{text}",
              SiteSetting.ai_embeddings_discourse_service_api_key,
            )
          else
            raise "No inference endpoint configured"
          end

        end

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

        def tokenizer
          DiscourseAi::Tokenizer::MultilingualE5LargeTokenizer
        end
      end
    end
  end
end
