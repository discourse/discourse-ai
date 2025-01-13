# frozen_string_literal: true
class DropOldEmbeddingTables < ActiveRecord::Migration[7.2]
  def up
    drop_table :ai_topic_embeddings
    drop_table :ai_post_embeddings
    drop_table :ai_document_fragment_embeddings

    execute <<~SQL
      DROP INDEX IF EXISTS ai_topic_embeddings_1_1_search_bit;
      DROP INDEX IF EXISTS ai_topic_embeddings_2_1_search_bit;
      DROP INDEX IF EXISTS ai_topic_embeddings_3_1_search_bit;
      DROP INDEX IF EXISTS ai_topic_embeddings_4_1_search_bit;
      DROP INDEX IF EXISTS ai_topic_embeddings_5_1_search_bit;
      DROP INDEX IF EXISTS ai_topic_embeddings_6_1_search_bit;
      DROP INDEX IF EXISTS ai_topic_embeddings_7_1_search_bit;
      DROP INDEX IF EXISTS ai_topic_embeddings_8_1_search_bit;

      DROP INDEX IF EXISTS ai_post_embeddings_1_1_search_bit;
      DROP INDEX IF EXISTS ai_post_embeddings_2_1_search_bit;
      DROP INDEX IF EXISTS ai_post_embeddings_3_1_search_bit;
      DROP INDEX IF EXISTS ai_post_embeddings_4_1_search_bit;
      DROP INDEX IF EXISTS ai_post_embeddings_5_1_search_bit;
      DROP INDEX IF EXISTS ai_post_embeddings_6_1_search_bit;
      DROP INDEX IF EXISTS ai_post_embeddings_7_1_search_bit;
      DROP INDEX IF EXISTS ai_post_embeddings_8_1_search_bit;

      DROP INDEX IF EXISTS ai_document_fragment_embeddings_1_1_search_bit;
      DROP INDEX IF EXISTS ai_document_fragment_embeddings_2_1_search_bit;
      DROP INDEX IF EXISTS ai_document_fragment_embeddings_3_1_search_bit;
      DROP INDEX IF EXISTS ai_document_fragment_embeddings_4_1_search_bit;
      DROP INDEX IF EXISTS ai_document_fragment_embeddings_5_1_search_bit;
      DROP INDEX IF EXISTS ai_document_fragment_embeddings_6_1_search_bit;
      DROP INDEX IF EXISTS ai_document_fragment_embeddings_7_1_search_bit;
      DROP INDEX IF EXISTS ai_document_fragment_embeddings_8_1_search_bit;
    SQL
  end

  def down
  end
end
