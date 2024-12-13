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
            truncation = DiscourseAi::Embeddings::Strategies::Truncation.new
            find_representation(SiteSetting.ai_embeddings_model).new(truncation)
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

        def initialize(strategy)
          @strategy = strategy
        end

        def vector_from(text, asymetric: false)
          raise NotImplementedError
        end

        def gen_bulk_reprensentations(relation)
          http_pool_size = 100
          pool =
            Concurrent::CachedThreadPool.new(
              min_threads: 0,
              max_threads: http_pool_size,
              idletime: 30,
            )

          schema = DiscourseAi::Embeddings::Schema.for(relation.first.class, vector: self)

          embedding_gen = inference_client
          promised_embeddings =
            relation
              .map do |record|
                prepared_text = prepare_text(record)
                next if prepared_text.blank?

                new_digest = OpenSSL::Digest::SHA1.hexdigest(prepared_text)
                next if schema.find_by_target(record)&.digest == new_digest

                Concurrent::Promises
                  .fulfilled_future(
                    { target: record, text: prepared_text, digest: new_digest },
                    pool,
                  )
                  .then_on(pool) do |w_prepared_text|
                    w_prepared_text.merge(embedding: embedding_gen.perform!(w_prepared_text[:text]))
                  end
              end
              .compact

          Concurrent::Promises
            .zip(*promised_embeddings)
            .value!
            .each { |e| schema.store(e[:target], e[:embedding], e[:digest]) }

          pool.shutdown
          pool.wait_for_termination
        end

        def generate_representation_from(target, persist: true)
          text = prepare_text(target)
          return if text.blank?

          schema = DiscourseAi::Embeddings::Schema.for(target.class, vector: self)

          new_digest = OpenSSL::Digest::SHA1.hexdigest(text)
          return if schema.find_by_target(target)&.digest == new_digest

          vector = vector_from(text)

          schema.store(target, vector, new_digest) if persist
        end

        def index_name(table_name)
          "#{table_name}_#{id}_#{@strategy.id}_search"
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
          raise NotImplementedError
        end

        def strategy_id
          @strategy.id
        end

        def strategy_version
          @strategy.version
        end

        protected

        def inference_client
          raise NotImplementedError
        end

        def prepare_text(record)
          @strategy.prepare_text_from(record, tokenizer, max_sequence_length - 2)
        end
      end
    end
  end
end
