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

        def prepare_text(text, asymetric: false)
          prepared_text = super(text, asymetric: asymetric)

          if prepared_text.present? && inference_client.class.name.include?("DiscourseClassifier")
            return "query: #{prepared_text}"
          end

          prepared_text
        end

        def prepare_target_text(target)
          prepared_text = super(target)

          if prepared_text.present? && inference_client.class.name.include?("DiscourseClassifier")
            return "query: #{prepared_text}"
          end

          prepared_text
        end
      end
    end
  end
end
