# frozen_string_literal: true

class CreateInferredConceptsPosts < ActiveRecord::Migration[7.0]
  def change
    create_table :inferred_concepts_posts, id: false do |t|
      t.belongs_to :inferred_concept
      t.belongs_to :post
      t.timestamps
    end
  end
end
