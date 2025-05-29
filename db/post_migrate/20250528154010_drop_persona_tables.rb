# frozen_string_literal: true

class DropPersonaTables < ActiveRecord::Migration[7.0]
  def up
    # Drop the old table after copying to new one
    drop_table :ai_personas if table_exists?(:ai_personas)

    # Remove old persona settings after copying to agent settings
    old_persona_settings = [
      'ai_summarization_persona',
      'ai_summary_gists_persona',
      'ai_bot_discover_persona',
      'ai_discord_search_persona'
    ]

    old_persona_settings.each do |setting|
      execute "DELETE FROM site_settings WHERE name = '#{setting}'"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot recreate dropped persona tables and settings"
  end
end
