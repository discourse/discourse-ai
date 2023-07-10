# frozen_string_literal: true

class CreateAiTopicEmbeddingsTable < ActiveRecord::Migration[7.0]
  def change
    models = [
      DiscourseAi::Embeddings::Models::AllMpnetBaseV2,
      DiscourseAi::Embeddings::Models::TextEmbeddingAda002,
    ]
    strategies = [DiscourseAi::Embeddings::Strategies::Truncation]

    models.each do |model|
      strategies.each do |strategy|
        table_name = "ai_topic_embeddings_#{model.id}_#{strategy.id}".to_sym

        create_table table_name, id: false do |t|
          t.integer :topic_id, null: false, primary_key: true
          t.integer :model_version, null: false
          t.integer :strategy_version, null: false
          t.text :digest, null: false
          t.column :embeddings, "vector(#{model.dimensions})", null: false
          t.timestamps
        end
      end
    end
  end
end
