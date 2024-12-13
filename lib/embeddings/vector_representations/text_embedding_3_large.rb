# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module VectorRepresentations
      class TextEmbedding3Large < Base
        class << self
          def name
            "text-embedding-3-large"
          end

          def correctly_configured?
            SiteSetting.ai_openai_api_key.present?
          end

          def dependant_setting_names
            %w[ai_openai_api_key]
          end
        end

        def id
          7
        end

        def version
          1
        end

        def dimensions
          # real dimentions are 3072, but we only support up to 2000 in the
          # indexes, so we downsample to 2000 via API
          2000
        end

        def max_sequence_length
          8191
        end

        def pg_function
          "<=>"
        end

        def tokenizer
          DiscourseAi::Tokenizer::OpenAiTokenizer
        end

        def inference_client
          DiscourseAi::Inference::OpenAiEmbeddings.instance(
            model: self.class.name,
            dimensions: dimensions,
          )
        end
      end
    end
  end
end
