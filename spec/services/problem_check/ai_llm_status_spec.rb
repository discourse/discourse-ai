# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProblemCheck::AiLlmStatus do
  subject(:check) { described_class.new }

  # let(:spec_model) do
  #   LlmModel.new(
  #     id: 50,
  #     display_name: "GPT-4 Turbo",
  #     name: "gpt-4-turbo",
  #     provider: "open_ai",
  #     tokenizer: "DiscourseAi::Tokenizer::OpenAiTokenizer",
  #     max_prompt_tokens: 131_072,
  #     api_key: "invalid",
  #     url: "https://api.openai.com/v1/chat/completions",
  #   )
  # end

  fab!(:llm_model)

  before do
    pp "Spec model: #{llm_model.inspect}"
    SiteSetting.ai_summarization_model = "custom:#{llm_model.id}"
    # assign_fake_provider_to(:ai_summarization_model)
    SiteSetting.ai_summarization_enabled = true
  end

  describe "#call" do
    it "does nothing if discourse-ai plugin disabled" do
      SiteSetting.discourse_ai_enabled = false
      expect(check).to be_chill_about_it
    end

    context "with discourse-ai plugin enabled for the site" do
      # let(:llm_model) { LlmModel.in_use.first }

      before { SiteSetting.discourse_ai_enabled = true }

      it "returns a problem with an LLM model" do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").with(
          body:
            "{\"model\":\"gpt-4-turbo\",\"messages\":[{\"role\":\"system\",\"content\":\"You are a helpful bot\"},{\"role\":\"user\",\"content\":\"How much is 1 + 1?\"}]}",
          headers: {
            "Accept" => "*/*",
            "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
            "Authorization" => "Bearer 123",
            "Content-Type" => "application/json",
            "Host" => "api.openai.com",
            "User-Agent" => "Ruby",
          },
        ).to_return(status: 200, body: "", headers: {})
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
