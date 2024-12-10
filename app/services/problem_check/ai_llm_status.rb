# frozen_string_literal: true

class ProblemCheck::AiLlmStatus < ProblemCheck
  self.priority = "high"
  # self.perform_every = 1.hour

  def call
    return no_problem if !SiteSetting.discourse_ai_enabled?
    return no_problem if llm_operational?

    problem
  end

  private

  def llm_operational?
    model_ids = DiscourseAi::Configuration::LlmEnumerator.global_usage.keys
    models_to_check = LlmModel.where(id: model_ids)

    models_to_check.each do |model|
      begin
        result = validator.run_test(model)
        return false unless result
      rescue StandardError => e
        Rails.logger.warn("LlmValidator encountered an error for model #{model.id}: #{e.message}")
        return false
      end
    end

    return true
  end

  def validator
    @validator ||= DiscourseAi::Configuration::LlmValidator.new
  end
end
