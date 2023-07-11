# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    class Manager
      attr_reader :target, :model, :strategy

      def initialize(target)
        @target = target
        @model =
          DiscourseAi::Embeddings::Models::Base.subclasses.find do
            _1.name == SiteSetting.ai_embeddings_model
          end
        @strategy = DiscourseAi::Embeddings::Strategies::Truncation.new(@target, @model)
      end

      def generate!
        @strategy.process!

        # TODO bail here if we already have an embedding with matching version and digest

        @embeddings = @model.generate_embeddings(@strategy.processed_target)

        persist!
      end

      def persist!
        begin
          DB.exec(
            <<~SQL,
                INSERT INTO ai_topic_embeddings_#{table_suffix} (topic_id, model_version, strategy_version, digest, embeddings, created_at, updated_at)
                VALUES (:topic_id, :model_version, :strategy_version, :digest, '[:embeddings]', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                ON CONFLICT (topic_id)
                DO UPDATE SET
                  model_version = :model_version,
                  strategy_version = :strategy_version,
                  digest = :digest,
                  embeddings = '[:embeddings]',
                  updated_at = CURRENT_TIMESTAMP

              SQL
            topic_id: @target.id,
            model_version: @model.version,
            strategy_version: @strategy.version,
            digest: @strategy.digest,
            embeddings: @embeddings,
          )
        rescue PG::Error => e
          Rails.logger.error(
            "Error #{e} persisting embedding for topic #{topic.id} and model #{model.name}",
          )
        end
      end

      def table_suffix
        "#{@model.id}_#{@strategy.id}"
      end

      def topic_embeddings_table
        "ai_topic_embeddings_#{table_suffix}"
      end
    end
  end
end
