# frozen_string_literal: true

module DiscourseAI
  module Embeddings
    class Topic
      DISCOURSE_MODELS = %w[all-mpnet-base-v2 msmarco-distilbert-base-v4]
      OPENAI_MODELS = %w[text-embedding-ada-002]

      def initialize(topic)
        @topic = topic
        @embeddings = {}
      end

      def perform!
        return unless SiteSetting.ai_embeddings_enabled
        return if enabled_models.empty?

        calculate_embeddings!
        persist_embeddings! unless @embeddings.empty?
      end

      def calculate_embeddings!
        return if @topic.blank? || @topic.first_post.blank?

        enabled_models.each do |model|
          @embeddings[model] = case
          when DISCOURSE_MODELS.include?(model)
            discourse_embeddings(model)
          when OPENAI_MODELS.include?(model)
            openai_embeddings
          end
        end
      end

      def persist_embeddings!
        return if @embeddings["all-mpnet-base-v2"].blank?
        @embeddings.each do |model, model_embeddings|
          case model
          when "all-mpnet-base-v2"
            DiscourseAI::Database::Connection.db.exec(
              <<~SQL,
                INSERT INTO topic_embeddings_symetric_discourse (topic_id, embeddings)
                VALUES (:topic_id, '[:embeddings]')
                ON CONFLICT (topic_id)
                DO UPDATE SET embeddings = '[:embeddings]'
              SQL
              topic_id: @topic.id,
              embeddings: model_embeddings,
            )
          when "msmarco-distilbert-base-v4"
            #todo
          when "text-embedding-ada-002"
            #todo
          end
        end
      end

      def discourse_embeddings(model)
        DiscourseAI::Inference::DiscourseClassifier.perform!(
          "#{SiteSetting.ai_embeddings_discourse_service_api_endpoint}/api/v1/classify",
          model.to_s,
          @topic.first_post.raw,
          SiteSetting.ai_embeddings_discourse_service_api_key,
        )
      end

      def openai_embeddings
        DiscourseAI::Inference::OpenAIEmbeddings.perform!(@topic.first_post.raw)
      end

      private

      def enabled_models
        SiteSetting.ai_embeddings_models.split("|")
      end
    end
  end
end
