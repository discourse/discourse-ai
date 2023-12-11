# frozen_string_literal: true

class CompletionPrompt < ActiveRecord::Base
  # TODO(roman): Remove may 2024.
  self.ignored_columns = ["provider"]

  TRANSLATE = -301
  GENERATE_TITLES = -307
  PROOFREAD = -303
  MARKDOWN_TABLE = -304
  CUSTOM_PROMPT = -305
  EXPLAIN = -306

  enum :prompt_type, { text: 0, list: 1, diff: 2 }

  validates :messages, length: { maximum: 20 }
  validate :each_message_length

  def self.enabled_by_name(name)
    where(enabled: true).find_by(name: name)
  end

  attr_accessor :custom_instruction

  def messages_with_input(input)
    return unless input

    user_input =
      if id == CUSTOM_PROMPT && custom_instruction.present?
        "#{custom_instruction}:\n#{input}"
      else
        input
      end

    messages_hash.merge(input: <<~TEXT)
    <input>
    #{user_input}
    </input>
    TEXT
  end

  private

  def messages_hash
    @messages_hash ||= messages.symbolize_keys!
  end

  def each_message_length
    messages.each_with_index do |msg, idx|
      next if msg["content"].length <= 1000

      errors.add(:messages, I18n.t("errors.prompt_message_length", idx: idx + 1))
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
#  messages        :jsonb
#
# Indexes
#
#  index_completion_prompts_on_name  (name)
#
