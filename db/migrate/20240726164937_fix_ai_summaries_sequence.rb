# frozen_string_literal: true

class FixAiSummariesSequence < ActiveRecord::Migration[7.0]
  def up
    execute <<-SQL
      SELECT
        SETVAL (
          'ai_summaries_id_seq',
          (
            SELECT
              GREATEST (
                (
                  SELECT
                    MAX(id)
                  FROM
                    summary_sections
                ),
                (
                  SELECT
                    max(id)
                  FROM
                    summary_sections
                )
              )
          ),
          true
        );
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
