# frozen_string_literal: true

class AddUniqueIndexToToolName < ActiveRecord::Migration[7.1]
  def change
    add_index :ai_tools, :name, unique: true, if_not_exists: true
  end
end
