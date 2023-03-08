# frozen_string_literal: true

module DiscourseAI
  module Embeddings
    class Topic
      DISCOURSE_MODELS = %i[all-mpnet-base-v2 msmarco-distilbert-base-v4]
      OPENAI_MODELS = %i[text-embedding-ada-002]

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
        pp @embeddings
        #TODO: persist embeddings
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
        SiteSetting.ai_embeddings_models.split("|").map(&:to_sym)
      end
    end
  end
end
