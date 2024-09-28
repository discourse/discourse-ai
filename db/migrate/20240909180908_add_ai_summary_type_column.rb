# frozen_string_literal: true
class AddAiSummaryTypeColumn < ActiveRecord::Migration[7.1]
  def change
    add_column :ai_summaries, :summary_type, :string
  end
end
