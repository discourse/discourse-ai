# frozen_string_literal: true

class CreatePostsInferredConcepts < ActiveRecord::Migration[7.0]
  def change
    create_table :posts_inferred_concepts, primary_key: %i[post_id inferred_concept_id] do |t|
      t.integer :post_id, null: false
      t.integer :inferred_concept_id, null: false
      t.timestamps
    end

    add_index :posts_inferred_concepts, :inferred_concept_id
  end
end
