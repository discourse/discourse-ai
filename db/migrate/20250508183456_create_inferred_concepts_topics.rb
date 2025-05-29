# frozen_string_literal: true

class CreateInferredConceptsTopics < ActiveRecord::Migration[7.0]
  def change
    create_table :inferred_concepts_topics, id: false do |t|
      t.bigint :inferred_concept_id
      t.bigint :topic_id
      t.timestamps
    end

    add_index :inferred_concepts_topics, %i[topic_id inferred_concept_id], unique: true
    add_index :inferred_concepts_topics, :inferred_concept_id
  end
end
