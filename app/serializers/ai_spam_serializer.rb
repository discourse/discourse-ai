# frozen_string_literal: true

class AiSpamSerializer < ApplicationSerializer
  attributes :is_enabled, :llm_id, :custom_instructions, :available_llms, :stats

  def is_enabled
    object[:enabled]
  end

  def llm_id
    settings&.llm_model&.id
  end

  def custom_instructions
    settings&.custom_instructions
  end

  def available_llms
    DiscourseAi::Configuration::LlmEnumerator.values.map do |hash|
      { id: hash[:value], name: hash[:name] }
    end
  end

  def stats
    {
      scanned_count: 1, # Replace with actual stats
      spam_detected: 2,
      false_positives: 3,
      false_negatives: 4,
    }
  end

  def settings
    object[:settings]
  end
end
