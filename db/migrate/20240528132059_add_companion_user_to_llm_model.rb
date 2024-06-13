# frozen_string_literal: true

class AddCompanionUserToLlmModel < ActiveRecord::Migration[7.0]
  def change
    add_column :llm_models, :bot_username, :string
    add_column :llm_models, :user_id, :integer
  end
end
