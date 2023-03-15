# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    class Models
      MODEL = Data.define(:name, :dimensions, :max_sequence_lenght, :functions, :type, :provider)

      def self.enabled_models
        setting = SiteSetting.ai_embeddings_models.split("|").map(&:strip)
        list.filter { |model| setting.include?(model.name) }
      end

      def self.list
        @@list ||= [
          MODEL.new("all-mpnet-base-v2", 768, 384, %i[dot cosine euclidean], [:symmetric], "discourse"),
          MODEL.new("all-distilroberta-v1", 768, 512, %i[dot cosine euclidean], [:symmetric], "discourse"),
          MODEL.new("multi-qa-mpnet-base-dot-v1", 768, 512, [:dot], [:symmetric], "discourse"),
          MODEL.new("paraphrase-multilingual-mpnet-base-v2", 768, 128, [:cosine], [:symmetric], "discourse"),
          MODEL.new("msmarco-distilbert-base-v4", 768, 512, [:cosine], [:asymmetric], "discourse"),
          MODEL.new("msmarco-distilbert-base-tas-b", 768, 512, [:dot], [:asymmetric], "discourse"),
          MODEL.new("text-embedding-ada-002", 1536, 2048, [:cosine], %i[:symmetric :asymmetric], "openai"),
        ]
      end
    end
  end
end
