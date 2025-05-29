# frozen_string_literal: true

class CreateInferredConceptsPosts < ActiveRecord::Migration[7.0]
  def change
    create_table :inferred_concepts_posts, id: false do |t|
      t.bigint :inferred_concept_id
      t.bigint :post_id
      t.timestamps
    end

    create_index :inferred_concepts_posts, %i[post_id inferred_concept_id], unique: true
    create_index :inferred_concepts_posts, :inferred_concept_id
  end
end
