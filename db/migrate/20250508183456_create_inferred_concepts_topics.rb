# frozen_string_literal: true

class CreateInferredConceptsTopics < ActiveRecord::Migration[7.0]
  def change
    create_table :inferred_concepts_topics, id: false do |t|
      t.belongs_to :inferred_concept
      t.belongs_to :topic
      t.timestamps
    end
  end
end
