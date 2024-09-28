# frozen_string_literal: true

class AiSummary < ActiveRecord::Base
  COMPLETE = "complete"
  GIST = "gist"

  belongs_to :target, polymorphic: true

  def mark_as_outdated
    @outdated = true
  end

  def outdated
    @outdated || false
  end
end

# == Schema Information
#
# Table name: ai_summaries
#
#  id                   :bigint           not null, primary key
#  target_id            :integer          not null
#  target_type          :string           not null
#  content_range        :int4range
#  summarized_text      :string           not null
#  original_content_sha :string           not null
#  algorithm            :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  summary_type         :string
#
# Indexes
#
#  index_ai_summaries_on_target_type_and_target_id  (target_type,target_id)
#
