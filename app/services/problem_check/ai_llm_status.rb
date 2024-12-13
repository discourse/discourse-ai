# frozen_string_literal: true

class ProblemCheck::AiLlmStatus < ProblemCheck
  self.priority = "high"
  self.perform_every = 6.hours

  def call
    llm_errors
  end

  private

  def llm_errors
    return [] if !SiteSetting.discourse_ai_enabled
    LlmModel.in_use.find_each.filter_map do |model|
      try_validate(model) { validator.run_test(model) }
    end
  end

  def try_validate(model, &blk)
    begin
      # raise({ message: "Forced error for testing" }.to_json) if Rails.env.test?
      blk.call
      nil
    rescue => e
      error_message = parse_error_message(e.message)
      message =
        "#{I18n.t("dashboard.problem.ai_llm_status", { model_name: model.display_name, model_id: model.id })}"

      Problem.new(
        message,
        priority: "high",
        identifier: "ai_llm_status",
        target: model.id,
        details: {
          model_id: model.id,
          model_name: model.display_name,
          error: error_message,
        },
      )
    end
  end

  def validator
    @validator ||= DiscourseAi::Configuration::LlmValidator.new
  end

  def parse_error_message(message)
    begin
      JSON.parse(message)["message"]
    rescue JSON::ParserError
      message.to_s
    end
  end
end
