# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module VectorRepresentations
      class MultilingualE5Large < Base
        class << self
          def name
            "multilingual-e5-large"
          end

          def correctly_configured?
            DiscourseAi::Inference::HuggingFaceTextEmbeddings.configured? ||
              (
                SiteSetting.ai_embeddings_discourse_service_api_endpoint_srv.present? ||
                  SiteSetting.ai_embeddings_discourse_service_api_endpoint.present?
              )
          end

          def dependant_setting_names
            %w[
              ai_hugging_face_tei_endpoint_srv
              ai_hugging_face_tei_endpoint
              ai_embeddings_discourse_service_api_key
              ai_embeddings_discourse_service_api_endpoint_srv
              ai_embeddings_discourse_service_api_endpoint
            ]
          end
        end

        def vector_from(text, asymetric: false)
          if DiscourseAi::Inference::HuggingFaceTextEmbeddings.configured?
            truncated_text = tokenizer.truncate(text, max_sequence_length - 2)
            DiscourseAi::Inference::HuggingFaceTextEmbeddings.perform!(truncated_text).first
          elsif discourse_embeddings_endpoint.present?
            DiscourseAi::Inference::DiscourseClassifier.perform!(
              "#{discourse_embeddings_endpoint}/api/v1/classify",
              self.class.name,
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
