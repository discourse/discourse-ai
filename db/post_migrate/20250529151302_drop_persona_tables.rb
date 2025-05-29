# frozen_string_literal: true

class DropPersonaTables < ActiveRecord::Migration[7.0]
  def up
    # Drop the old table after copying to new one
    drop_table :ai_personas if table_exists?(:ai_personas)
  end

  def down
    raise IrreversibleMigration, "Cannot recreate dropped persona tables"
  end
end
