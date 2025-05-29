# frozen_string_literal: true

class CopyPersonaTablesToAgent < ActiveRecord::Migration[7.0]
  def up
    # Copy the main table structure and data
    if table_exists?(:ai_personas) && !table_exists?(:ai_agents)
      execute <<~SQL
        CREATE TABLE ai_agents AS
        SELECT * FROM ai_personas
      SQL

      # Copy indexes from ai_personas to ai_agents
      execute <<~SQL
        CREATE UNIQUE INDEX index_ai_agents_on_id
        ON ai_agents USING btree (id)
      SQL

      # Copy any other indexes that exist on ai_personas
      indexes = execute(<<~SQL).to_a
        SELECT indexname, indexdef
        FROM pg_indexes
        WHERE tablename = 'ai_personas'
        AND indexname != 'ai_personas_pkey'
      SQL

      indexes.each do |index|
        new_index_def = index['indexdef'].gsub('ai_personas', 'ai_agents')
        new_index_name = index['indexname'].gsub('ai_personas', 'ai_agents')
        new_index_def = new_index_def.gsub(index['indexname'], new_index_name)
        execute(new_index_def)
      end
    end

    # Update polymorphic associations to point to new table
    execute <<~SQL
      UPDATE rag_document_fragments
      SET target_type = 'AiAgent'
      WHERE target_type = 'AiPersona'
    SQL

    execute <<~SQL
      UPDATE upload_references
      SET target_type = 'AiAgent'
      WHERE target_type = 'AiPersona'
    SQL
  end

  def down
    drop_table :ai_agents if table_exists?(:ai_agents)

    # Revert polymorphic associations
    execute <<~SQL
      UPDATE rag_document_fragments
      SET target_type = 'AiPersona'
      WHERE target_type = 'AiAgent'
    SQL

    execute <<~SQL
      UPDATE upload_references
      SET target_type = 'AiPersona'
      WHERE target_type = 'AiAgent'
    SQL
  end
end
