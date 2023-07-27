# frozen_string_literal: true

class CreateMultilingualTopicEmbeddingsTable < ActiveRecord::Migration[7.0]
  def change
    models = [DiscourseAi::Embeddings::Models::MultilingualE5Large]
    strategies = [DiscourseAi::Embeddings::Strategies::Truncation]

    models.each do |model|
      strategies.each do |strategy|
        table_name = "ai_topic_embeddings_#{model.id}_#{strategy.id}".to_sym

        create_table table_name, id: false do |t|
          t.integer :topic_id, null: false
          t.integer :model_version, null: false
          t.integer :strategy_version, null: false
          t.text :digest, null: false
          t.column :embeddings, "vector(#{model.dimensions})", null: false
          t.timestamps

          t.index :topic_id, unique: true
        end
      end
    end
  end
end
