# frozen_string_literal: true
class DropOldEmbeddingTables < ActiveRecord::Migration[7.2]
  def up
    drop_table :ai_topic_embeddings
    drop_table :ai_post_embeddings
    drop_table :ai_document_fragment_embeddings
  end

  def down
  end
end
