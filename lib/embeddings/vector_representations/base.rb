# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module VectorRepresentations
      class Base
        class << self
          def find_representation(model_name)
            # we are explicit here cause the loader may have not
            # loaded the subclasses yet
            [
              DiscourseAi::Embeddings::VectorRepresentations::AllMpnetBaseV2,
              DiscourseAi::Embeddings::VectorRepresentations::BgeLargeEn,
              DiscourseAi::Embeddings::VectorRepresentations::BgeM3,
              DiscourseAi::Embeddings::VectorRepresentations::Gemini,
              DiscourseAi::Embeddings::VectorRepresentations::MultilingualE5Large,
              DiscourseAi::Embeddings::VectorRepresentations::TextEmbedding3Large,
              DiscourseAi::Embeddings::VectorRepresentations::TextEmbedding3Small,
              DiscourseAi::Embeddings::VectorRepresentations::TextEmbeddingAda002,
            ].find { _1.name == model_name }
          end

          def current_representation
            find_representation(SiteSetting.ai_embeddings_model).new
          end

          def correctly_configured?
            raise NotImplementedError
          end

          def dependant_setting_names
            raise NotImplementedError
          end

          def configuration_hint
            settings = dependant_setting_names
            I18n.t(
              "discourse_ai.embeddings.configuration.hint",
              settings: settings.join(", "),
              count: settings.length,
            )
          end
        end

        def name
          raise NotImplementedError
        end

        def dimensions
          raise NotImplementedError
        end

        def max_sequence_length
          raise NotImplementedError
        end

        def id
          raise NotImplementedError
        end

        def pg_function
          raise NotImplementedError
        end

        def version
          raise NotImplementedError
        end

        def tokenizer
          raise NotImplementedError
        end

        def asymmetric_query_prefix
          ""
        end

        def strategy_id
          strategy.id
        end

        def strategy_version
          strategy.version
        end

        def prepare_query_text(text, asymetric: false)
          strategy.prepare_query_text(text, self, asymetric: asymetric)
        end

        def prepare_target_text(target)
          strategy.prepare_target_text(target, self)
        end

        def strategy
          @strategy ||= DiscourseAi::Embeddings::Strategies::Truncation.new
        end

        def inference_client
          raise NotImplementedError
        end
      end
    end
  end
end
