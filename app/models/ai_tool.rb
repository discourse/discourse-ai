# frozen_string_literal: true

class AiTool < ActiveRecord::Base
  validates :name, presence: true, length: { maximum: 255 }
  validates :description, presence: true, length: { maximum: 1000 }
  validates :script, presence: true, length: { maximum: 100_000 }
  validates :created_by_id, presence: true
  belongs_to :created_by, class_name: "User"

  def signature
    { name: name, description: description, parameters: parameters.map(&:symbolize_keys) }
  end

  def runner(parameters, llm:, bot_user:, context: {})
    DiscourseAi::AiBot::ToolRunner.new(
      parameters,
      llm: llm,
      bot_user: bot_user,
      context: context,
      tool: self,
    )
  end

  after_commit :bump_persona_cache

  def bump_persona_cache
    AiPersona.persona_cache.flush!
  end
end

# == Schema Information
#
# Table name: ai_tools
#
#  id            :bigint           not null, primary key
#  name          :string           not null
#  description   :text             not null
#  parameters    :jsonb            not null
#  script        :text             not null
#  created_by_id :integer          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
