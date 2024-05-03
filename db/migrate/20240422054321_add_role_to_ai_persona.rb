# frozen_string_literal: true

class AddRoleToAiPersona < ActiveRecord::Migration[7.0]
  def change
    create_enum :ai_persona_role, %w[bot topic_responder message_responder summarizer]
    add_column :ai_personas, :role, :enum, default: "bot", null: false, enum_type: :ai_persona_role

    add_column :ai_personas, :role_category_ids, :integer, array: true, default: [], null: false
    add_column :ai_personas, :role_tags, :string, array: true, default: [], null: false
    add_column :ai_personas, :role_group_ids, :integer, array: true, default: [], null: false
    add_column :ai_personas, :role_whispers, :boolean, default: false, null: false
    add_column :ai_personas, :role_max_responses_per_hour, :integer, default: 50, null: false
  end
end
