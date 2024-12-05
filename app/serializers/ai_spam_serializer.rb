# frozen_string_literal: true

class AiSpamSerializer < ApplicationSerializer
  attributes :is_enabled, :selected_llm, :custom_instructions, :available_llms, :stats

  def is_enabled
    # Read from your hidden setting
    SiteSetting.ai_spam_detection_enabled
  end

  def selected_llm
    SiteSetting.ai_spam_detection_model
  end

  def custom_instructions
    SiteSetting.ai_spam_detection_custom_instructions
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
end
