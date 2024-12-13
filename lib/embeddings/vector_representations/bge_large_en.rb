# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module VectorRepresentations
      class BgeLargeEn < Base
        class << self
          def name
            "bge-large-en"
          end

          def correctly_configured?
            SiteSetting.ai_cloudflare_workers_api_token.present? ||
              DiscourseAi::Inference::HuggingFaceTextEmbeddings.configured? ||
              (
                SiteSetting.ai_embeddings_discourse_service_api_endpoint_srv.present? ||
                  SiteSetting.ai_embeddings_discourse_service_api_endpoint.present?
              )
          end

          def dependant_setting_names
            %w[
              ai_cloudflare_workers_api_token
              ai_hugging_face_tei_endpoint_srv
              ai_hugging_face_tei_endpoint
              ai_embeddings_discourse_service_api_key
              ai_embeddings_discourse_service_api_endpoint_srv
              ai_embeddings_discourse_service_api_endpoint
            ]
          end
        end

        def dimensions
          1024
        end

        def max_sequence_length
          512
        end

        def id
          4
        end

        def version
          1
        end

        def pg_function
          "<#>"
        end

        def tokenizer
          DiscourseAi::Tokenizer::BgeLargeEnTokenizer
        end

        def asymmetric_query_prefix
          "Represent this sentence for searching relevant passages:"
        end

        def inference_client
          inference_model_name = "baai/bge-large-en-v1.5"

          if SiteSetting.ai_cloudflare_workers_api_token.present?
            DiscourseAi::Inference::CloudflareWorkersAi.instance(inference_model_name)
          elsif DiscourseAi::Inference::HuggingFaceTextEmbeddings.configured?
            DiscourseAi::Inference::HuggingFaceTextEmbeddings.instance
          elsif SiteSetting.ai_embeddings_discourse_service_api_endpoint_srv.present? ||
                SiteSetting.ai_embeddings_discourse_service_api_endpoint.present?
            DiscourseAi::Inference::DiscourseClassifier.instance(
              inference_model_name.split("/").last,
            )
          else
            raise "No inference endpoint configured"
          end
        end
      end
    end
  end
end
