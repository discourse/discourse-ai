# frozen_string_literal: true

class LlmQuota < ActiveRecord::Base
  self.table_name = "llm_quotas"

  belongs_to :group
  belongs_to :llm_model
  has_many :llm_quota_usages

  validates :group_id, presence: true
  validates :llm_model_id, presence: true
  validates :duration_seconds, presence: true, numericality: { greater_than: 0 }
  validates :max_tokens, numericality: { greater_than: 0, allow_nil: true }
  validates :max_usages, numericality: { greater_than: 0, allow_nil: true }

  validate :at_least_one_limit

  def self.within_quota?(llm, user)
  end

  def self.log_usage(llm, user, input_tokens, output_tokens)
  end

  def available_tokens
    max_tokens
  end

  def available_usages
    max_usages
  end

  private

  def at_least_one_limit
    if max_tokens.nil? && max_usages.nil?
      errors.add(:base, I18n.t("discourse_ai.errors.quota_required"))
    end
  end
end

# == Schema Information
#
# Table name: llm_quotas
#
#  id               :bigint           not null, primary key
#  group_id         :bigint           not null
#  llm_model_id     :bigint           not null
#  max_tokens       :integer
#  max_usages       :integer
#  duration_seconds :integer          not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
