# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module VectorRepresentations
      class TextEmbedding3Small < Base
        class << self
          def name
            "text-embedding-3-small"
          end

          def correctly_configured?
            SiteSetting.ai_openai_api_key.present?
          end

          def dependant_setting_names
            %w[ai_openai_api_key]
          end
        end

        def id
          6
        end

        def version
          1
        end

        def dimensions
          1536
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
          DiscourseAi::Inference::OpenAiEmbeddings.instance(model: self.class.name)
        end
      end
    end
  end
end
