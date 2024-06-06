# frozen_string_literal: true

class CopySummarySectionsToAiSummaries < ActiveRecord::Migration[7.0]
  def up
    execute <<-SQL
      INSERT INTO ai_summaries (id, target_id, target_type, content_range, summarized_text, meta_section_id, original_content_sha, algorithm, created_at, updated_at)
      SELECT id, target_id, target_type, content_range, summarized_text, meta_section_id, original_content_sha, algorithm, created_at, updated_at
      FROM summary_sections
    SQL
  end

  def down
    execute "DELETE FROM ai_summaries"
  end
end
