# frozen_string_literal: true

class ModelAccuracy < ActiveRecord::Base
  def self.adjust_model_accuracy(new_status, reviewable)
    return unless %i[approved rejected].include?(new_status)
    return unless [ReviewableAiPost, ReviewableAiChatMessage].include?(reviewable.class)

    verdicts = reviewable.payload.to_h["verdicts"] || {}

    verdicts.each do |model_name, verdict|
      accuracy_model = find_by(model: model_name)

      attribute =
        if verdict
          new_status == :approved ? :flags_agreed : :flags_disagreed
        else
          new_status == :rejected ? :flags_agreed : :flags_disagreed
        end

      accuracy_model.increment!(attribute)
    end
  end

  def calculate_accuracy
    return 0 if total_flags.zero?

    (flags_agreed * 100) / total_flags
  end

  private

  def total_flags
    flags_agreed + flags_disagreed
  end
end
