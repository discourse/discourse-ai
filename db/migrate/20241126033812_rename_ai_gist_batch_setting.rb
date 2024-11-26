# frozen_string_literal: true

class RenameAiGistBatchSetting < ActiveRecord::Migration[7.0]
  def up
    execute "UPDATE site_settings SET name = 'ai_summary_gists_enabled', value = 't', data_type = 5 WHERE name = 'ai_summarize_max_topic_gists_per_batch'"
    execute "UPDATE site_settings SET name = 'ai_summary_gists_allowed_groups'  WHERE name = 'ai_hot_topic_gists_allowed_groups'"
  end

  def down
    execute "UPDATE site_settings SET name = 'ai_summarize_max_topic_gists_per_batch', value = '10', data_type = 3 WHERE name = 'ai_summary_gists_enabled'"
    execute "UPDATE site_settings SET name = 'ai_hot_topic_gists_allowed_groups' WHERE name = 'ai_summary_gists_allowed_groups'"
  end
end
