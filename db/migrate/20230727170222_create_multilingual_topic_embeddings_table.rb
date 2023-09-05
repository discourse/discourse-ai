# frozen_string_literal: true

class CreateMultilingualTopicEmbeddingsTable < ActiveRecord::Migration[7.0]
  def change
    truncation = DiscourseAi::Embeddings::Strategies::Truncation.new
    vector_rep = DiscourseAi::Embeddings::VectorRepresentations::MultilingualE5Large.new(truncation)

    create_table vector_rep.table_name.to_sym, id: false do |t|
      t.integer :topic_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "vector(#{vector_rep.dimensions})", null: false
      t.timestamps

      t.index :topic_id, unique: true
    end
  end
end
