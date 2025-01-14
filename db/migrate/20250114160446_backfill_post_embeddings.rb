# frozen_string_literal: true
class BackfillPostEmbeddings < ActiveRecord::Migration[7.2]
  def up
    not_backfilled = DB.query_single("SELECT COUNT(*) FROM ai_posts_embeddings").first.to_i == 0

    if not_backfilled
      # Copy data from old tables to new tables
      execute <<~SQL
        INSERT INTO ai_posts_embeddings (post_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
        SELECT * FROM ai_post_embeddings;
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
