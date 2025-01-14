# frozen_string_literal: true
class BackfillTopicEmbeddings < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    loop do
      count = execute(<<~SQL).cmd_tuples
      INSERT INTO ai_topics_embeddings (topic_id, model_id, model_version, strategy_id, strategy_version, digest, embeddings, created_at, updated_at)
        SELECT source.*
        FROM ai_topic_embeddings source
        WHERE NOT EXISTS (
          SELECT 1 
          FROM ai_topics_embeddings target 
          WHERE target.model_id = source.model_id
            AND target.strategy_id = source.strategy_id
            AND target.topic_id = source.topic_id
        )
        LIMIT 10000
      SQL

      break if count == 0
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
