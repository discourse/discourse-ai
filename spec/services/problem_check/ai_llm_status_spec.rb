# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProblemCheck::AiLlmStatus do
  subject(:check) { described_class.new }

  before do
    assign_fake_provider_to(:ai_summarization_model)
    SiteSetting.ai_summarization_enabled = true
  end

  describe "#call" do
    it "does nothing if discourse-ai plugin disabled" do
      SiteSetting.discourse_ai_enabled = false
      expect(check).to be_chill_about_it
    end

    context "with discourse-ai plugin enabled for the site" do
      let(:llm_model) { LlmModel.in_use.first }

      before { SiteSetting.discourse_ai_enabled = true }

      it "returns a problem with an LLM model" do
        message =
          "#{I18n.t("dashboard.problem.ai_llm_status", { model_name: llm_model.display_name, model_id: llm_model.id })}"

        expect(described_class.new.call).to contain_exactly(
          have_attributes(
            identifier: "ai_llm_status",
            target: llm_model.id,
            priority: "high",
            message: message,
            details: {
              model_id: llm_model.id,
              model_name: llm_model.display_name,
              error: "Forced error for testing",
            },
          ),
        )
      end
    end
  end
end
