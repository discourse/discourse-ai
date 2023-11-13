# frozen_string_literal: true

require_relative "../../support/toxicity_inference_stubs"

RSpec.describe "Toxicity-flagged chat messages", type: :system, js: true do
  fab!(:chat_message) { Fabricate(:chat_message) }
  fab!(:admin) { Fabricate(:admin) }

  before do
    sign_in(admin)
    SiteSetting.ai_toxicity_enabled = true
    SiteSetting.ai_toxicity_flag_automatically = true

    ToxicityInferenceStubs.stub_chat_message_classification(chat_message, toxic: true)

    DiscourseAi::ChatMessageClassificator.new(
      DiscourseAi::Toxicity::ToxicityClassification.new,
    ).classify!(chat_message)
  end

  it "displays them in the review queue" do
    visit("/review")

    expect(page).to have_selector(".reviewable-ai-chat-message .reviewable-actions")
  end
end
