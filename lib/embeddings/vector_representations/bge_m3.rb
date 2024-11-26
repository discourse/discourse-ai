# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module VectorRepresentations
      class BgeM3 < Base
        class << self
          def name
            "bge-m3"
          end

          def correctly_configured?
            DiscourseAi::Inference::HuggingFaceTextEmbeddings.configured?
          end

          def dependant_setting_names
            %w[ai_hugging_face_tei_endpoint_srv ai_hugging_face_tei_endpoint]
          end
        end

        def vector_from(text, asymetric: false)
          truncated_text = tokenizer.truncate(text, max_sequence_length - 2)
          inference_client.perform!(truncated_text)
        end

        def dimensions
          1024
        end

        def max_sequence_length
          8192
        end

        def id
          8
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
          DiscourseAi::Tokenizer::BgeM3Tokenizer
        end

        def inference_client
          DiscourseAi::Inference::HuggingFaceTextEmbeddings.instance
        end
      end
    end
  end
end
