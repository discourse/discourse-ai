# frozen_string_literal: true

class NewEmbeddingsTables < ActiveRecord::Migration[7.2]
  def up
    create_table :ai_topics_embeddings, id: false do |t|
      t.bigint :topic_id, null: false
      t.bigint :model_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_id, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "halfvec", null: false
      t.timestamps

      t.index %i[model_id strategy_id topic_id],
              unique: true,
              name: "index_ai_topics_embeddings_on_model_strategy_topic"
    end

    create_table :ai_posts_embeddings, id: false do |t|
      t.bigint :post_id, null: false
      t.bigint :model_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_id, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "halfvec", null: false
      t.timestamps

      t.index %i[model_id strategy_id post_id],
              unique: true,
              name: "index_ai_posts_embeddings_on_model_strategy_post"
    end

    create_table :ai_document_fragments_embeddings, id: false do |t|
      t.bigint :rag_document_fragment_id, null: false
      t.bigint :model_id, null: false
      t.integer :model_version, null: false
      t.integer :strategy_id, null: false
      t.integer :strategy_version, null: false
      t.text :digest, null: false
      t.column :embeddings, "halfvec", null: false
      t.timestamps

      t.index %i[model_id strategy_id rag_document_fragment_id],
              unique: true,
              name: "index_ai_fragments_embeddings_on_model_strategy_fragment"
    end

    # Copied from 20241008054440_create_binary_indexes_for_embeddings
    %w[topics posts document_fragments].each do |type|
      # our supported embeddings models IDs and dimensions
      [
        [1, 768],
        [2, 1536],
        [3, 1024],
        [4, 1024],
        [5, 768],
        [6, 1536],
        [7, 2000],
        [8, 1024],
      ].each { |model_id, dimensions| execute <<-SQL }
        CREATE INDEX ai_#{type}_embeddings_#{model_id}_1_search_bit ON ai_#{type}_embeddings
        USING hnsw ((binary_quantize(embeddings)::bit(#{dimensions})) bit_hamming_ops)
        WHERE model_id = #{model_id} AND strategy_id = 1;
      SQL
    end

    # Copy data from old tables to new tables
    execute <<-SQL
      INSERT INTO ai_topics_embeddings (topic_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT * FROM ai_topic_embeddings;

      INSERT INTO ai_posts_embeddings (post_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT * FROM ai_post_embeddings;

      INSERT INTO ai_document_fragments_embeddings (rag_document_fragment_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
      SELECT * FROM ai_document_fragment_embeddings;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
