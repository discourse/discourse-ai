# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    class Topic
      def initialize(topic)
        @topic = topic
        @embeddings = {}
      end

      def perform!
        return unless SiteSetting.ai_embeddings_enabled
        return if DiscourseAi::Embeddings::Models.enabled_models.empty?

        calculate_embeddings!
        persist_embeddings! unless @embeddings.empty?
      end

      def calculate_embeddings!
        return if @topic.blank? || @topic.first_post.blank?

        DiscourseAi::Embeddings::Models.enabled_models.each do |model|
          @embeddings[model.name] = send("#{model.provider}_embeddings", model.name)
        end
      end

      def persist_embeddings!
        @embeddings.each do |model, model_embeddings|
          DiscourseAi::Database::Connection.db.exec(
            <<~SQL,
              INSERT INTO topic_embeddings_#{model.underscore} (topic_id, embeddings)
              VALUES (:topic_id, '[:embeddings]')
              ON CONFLICT (topic_id)
              DO UPDATE SET embeddings = '[:embeddings]'
            SQL
            topic_id: @topic.id,
            embeddings: model_embeddings,
          )
        end
      end

      def discourse_embeddings(model)
        DiscourseAi::Inference::DiscourseClassifier.perform!(
          "#{SiteSetting.ai_embeddings_discourse_service_api_endpoint}/api/v1/classify",
          model.to_s,
          @topic.first_post.raw,
          SiteSetting.ai_embeddings_discourse_service_api_key,
        )
      end

      def openai_embeddings(model)
        response = DiscourseAi::Inference::OpenAIEmbeddings.perform!(@topic.first_post.raw)
        response[:data].first[:embedding]
      end
    end
  end
end
