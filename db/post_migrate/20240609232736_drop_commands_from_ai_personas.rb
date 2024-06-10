# frozen_string_literal: true
class DropCommandsFromAiPersonas < ActiveRecord::Migration[7.0]
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  def up
    Migration::ColumnDropper.drop_readonly(:ai_personas, :commands)
    remove_column :ai_personas, :commands
  end
end
