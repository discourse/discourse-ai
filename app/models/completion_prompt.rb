# frozen_string_literal: true

class CompletionPrompt < ActiveRecord::Base
  enum :prompt_type, { text: 0, list: 1, diff: 2 }
end

# == Schema Information
#
# Table name: completion_prompts
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  translated_name :string
#  prompt_type     :integer          default("text"), not null
#  value           :text             not null
#  enabled         :boolean          default(TRUE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_completion_prompts_on_name  (name) UNIQUE
#
