# frozen_string_literal: true

class AddToolNameToAiTools < ActiveRecord::Migration[7.1]
  def change
    add_column :ai_tools, :tool_name, :string, null: false, default: "", if_not_exists: true
    add_index :ai_tools, :tool_name, unique: true, if_not_exists: true
  end
end
