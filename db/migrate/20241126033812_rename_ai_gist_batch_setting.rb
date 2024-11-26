# frozen_string_literal: true

class RenameAiGistBatchSetting < ActiveRecord::Migration[7.0]
  def up
    execute "UPDATE site_settings SET name = 'ai_summarize_max_topic_gists_per_batch'  WHERE name = 'ai_summarize_max_hot_topics_gists_per_batch'"
  end

  def down
    execute "UPDATE site_settings SET name = 'ai_summarize_max_hot_topics_gists_per_batch' WHERE name = 'ai_summarize_max_topic_gists_per_batch'"
  end
end
