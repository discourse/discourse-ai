# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module VectorRepresentations
      class MxbaiEmbedXsmallV1 < Base
        class << self
          def name
            "mxbai-embed-xsmall-v1"
          end

          def correctly_configured?
            SiteSetting.ai_embeddings_discourse_service_api_endpoint_srv.present? ||
              SiteSetting.ai_embeddings_discourse_service_api_endpoint.present?
          end

          def dependant_setting_names
            %w[
              ai_embeddings_discourse_service_api_key
              ai_embeddings_discourse_service_api_endpoint_srv
              ai_embeddings_discourse_service_api_endpoint
            ]
          end
        end

        def vector_from(text, asymetric: false)
          inference_client.perform!(text)
        end

        def dimensions
          384
        end

        def max_sequence_length
          512
        end

        def id
          1
        end

        def version
          1
        end

        def pg_function
          "<#>"
        end

        def pg_index_type
          "halfvec_ip_ops"
        end

        def tokenizer
          DiscourseAi::Tokenizer::MxbaiEmbedXsmallV1Tokenizer
        end

        def inference_client
          DiscourseAi::Inference::DiscourseClassifier.instance(self.class.name)
        end
      end
    end
  end
end
