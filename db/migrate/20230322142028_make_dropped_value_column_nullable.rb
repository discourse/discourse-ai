# frozen_string_literal: true
class MakeDroppedValueColumnNullable < ActiveRecord::Migration[7.0]
  def up
    column_exists = DB.exec(<<~SQL) == 1
      SELECT 1
      FROM INFORMATION_SCHEMA.COLUMNS
      WHERE
        table_schema = 'public' AND
        table_name = 'completion_prompts' AND
        column_name = 'value'
    SQL

    if column_exists
      Migration::SafeMigrate.disable!
      change_column_null :completion_prompts, :value, true
      Migration::SafeMigrate.enable!
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
