# frozen_string_literal: true

class CompletionPrompt < ActiveRecord::Base
  # TODO(roman): Remove sept 2023.
  self.ignored_columns = ["value"]

  VALID_ROLES = %w[system user assistant]

  enum :prompt_type, { text: 0, list: 1, diff: 2 }

  validates :messages, length: { maximum: 20 }
  validate :each_message_length
  validate :each_message_role

  def messages_with_user_input(user_input)
    self.messages << { role: "user", content: user_input }
  end

  private

  def each_message_length
    messages.each_with_index do |msg, idx|
      next if msg["content"].length <= 1000

      errors.add(:messages, I18n.t("errors.prompt_message_length", idx: idx + 1))
    end
  end

  def each_message_role
    messages.each_with_index do |msg, idx|
      next if VALID_ROLES.include?(msg["role"])

      errors.add(:messages, I18n.t("errors.invalid_prompt_role", idx: idx + 1))
    end
  end
end

# == Schema Information
#
# Table name: completion_prompts
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  translated_name :string
#  prompt_type     :integer          default("text"), not null
#  enabled         :boolean          default(TRUE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  messages        :jsonb            not null
#
# Indexes
#
#  index_completion_prompts_on_name  (name) UNIQUE
#
