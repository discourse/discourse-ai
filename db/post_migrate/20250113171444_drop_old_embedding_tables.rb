# frozen_string_literal: true
class DropOldEmbeddingTables < ActiveRecord::Migration[7.2]
  def up
    # Copy rag embeddings created during deploy.
    execute <<~SQL
      INSERT INTO ai_document_fragments_embeddings (rag_document_fragment_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      (
        SELECT  ai_document_fragment_embeddings.*
        FROM ai_document_fragment_embeddings 
        LEFT OUTER JOIN ai_document_fragments_embeddings ON ai_document_fragment_embeddings.rag_document_fragment_id = ai_document_fragments_embeddings.rag_document_fragment_id
        WHERE ai_document_fragments_embeddings.rag_document_fragment_id IS NULL
      )
    SQL

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

    drop_table :ai_topic_embeddings
    drop_table :ai_post_embeddings
    drop_table :ai_document_fragment_embeddings
  end

  def down
  end
end
