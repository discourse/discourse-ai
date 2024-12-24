# frozen_string_literal: true

class RemoveDetectTextLocalePrompt < ActiveRecord::Migration[7.0]
  def up
    execute "DELETE FROM completion_prompts WHERE id = -309"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
