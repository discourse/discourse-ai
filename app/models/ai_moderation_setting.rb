class AiModerationSetting < ActiveRecord::Base
  belongs_to :llm_model

  validates :setting_type, presence: true
  validates :setting_type, uniqueness: true

  def self.spam
    find_by(setting_type: :spam)
  end

  def custom_instructions
    data["custom_instructions"]
  end
end
