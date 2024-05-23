# frozen_string_literal: true

class CustomFieldsToTrackAiBotUsers < ActiveRecord::Migration[7.0]
  def up
    existing_bot_user_ids = DB.query_single("SELECT id FROM users WHERE id <= -110 AND id >= -121")

    custom_field_rows =
      existing_bot_user_ids
        .map { |id| "(bot_model_name, #{id_to_model_name(id)}, #{id})" }
        .join(",")

    DB.exec(<<~SQL, rows: custom_field_rows) if custom_field_rows.present?
        INSERT INTO user_custom_fields (name, value, user_id)
        VALUES :rows;
      SQL
  end

  def id_to_model_name(id)
    # Skip -116. fake model.
    case id
    when -110
      "gpt-4"
    when -111
      "gpt-3.5-turbo"
    when -112
      "claude-2"
    when -113
      "gpt-4-turbo"
    when -114
      "mixtral-8x7B-Instruct-V0.1"
    when -115
      "gemini-1.5-pro"
    when -116
      "fake"
    when -117
      "claude-3-opus"
    when -118
      "claude-3-sonnet"
    when -119
      "claude-3-haiku"
    when -120
      "cohere-command-r-plus"
    else
      "gpt-4o"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
