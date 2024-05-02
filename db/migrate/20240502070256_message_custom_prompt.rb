# frozen_string_literal: true
class MessageCustomPrompt < ActiveRecord::Migration[7.0]
  def change
    create_table :message_custom_prompts do |t|
      t.bigint :message_id, null: false
      t.json :custom_prompt, null: false
      t.timestamps
    end

    add_index :message_custom_prompts, :message_id, unique: true
  end
end
