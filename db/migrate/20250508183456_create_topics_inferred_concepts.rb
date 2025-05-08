# frozen_string_literal: true

class CreateTopicsInferredConcepts < ActiveRecord::Migration[7.0]
  def change
    create_table :topics_inferred_concepts do |t|
      t.integer :topic_id, null: false
      t.integer :inferred_concept_id, null: false
      t.timestamps
    end

    add_index :topics_inferred_concepts, [:topic_id, :inferred_concept_id], unique: true, name: 'idx_unique_topic_inferred_concept'
    add_index :topics_inferred_concepts, :topic_id
    add_index :topics_inferred_concepts, :inferred_concept_id
  end
end