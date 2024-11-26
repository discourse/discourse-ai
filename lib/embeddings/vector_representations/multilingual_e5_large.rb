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
          client = inference_client

          needs_truncation = client.class.name.include?("HuggingFaceTextEmbeddings")
          if needs_truncation
            text = tokenizer.truncate(text, max_sequence_length - 2)
          else
            text = "query: #{text}"
          end

          client.perform!(text)
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
          "halfvec_cosine_ops"
        end

        def tokenizer
          DiscourseAi::Tokenizer::MultilingualE5LargeTokenizer
        end

        def inference_client
          if DiscourseAi::Inference::HuggingFaceTextEmbeddings.configured?
            DiscourseAi::Inference::HuggingFaceTextEmbeddings.instance
          elsif SiteSetting.ai_embeddings_discourse_service_api_endpoint_srv.present? ||
                SiteSetting.ai_embeddings_discourse_service_api_endpoint.present?
            DiscourseAi::Inference::DiscourseClassifier.instance(self.class.name)
          else
            raise "No inference endpoint configured"
          end
        end
      end
    end
  end
end
