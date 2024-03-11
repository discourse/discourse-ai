# frozen_string_literal: true

class AddSharedAiConversations < ActiveRecord::Migration[7.0]
  def change
    create_table :shared_ai_conversations do |t|
      t.integer :user_id, null: false
      t.integer :topic_id, null: false
      t.string :title, null: false, max_length: 1024
      t.string :llm_name, null: false, max_length: 1024
      t.jsonb :posts, null: false
      t.string :share_key, null: false, index: { unique: true }
      t.string :excerpt, null: false, max_length: 10_000
      t.timestamps
    end

    add_index :shared_ai_conversations, :topic_id, unique: true
    add_index :shared_ai_conversations, %i[user_id topic_id], unique: true
  end
end
