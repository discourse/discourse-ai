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

  context "when the message is hard deleted" do
    before { chat_message.destroy! }

    it "does not throw an error" do
      visit("/review")

      expect(page).to have_selector(".reviewable-ai-chat-message .reviewable-actions")
    end

    it "adds the option to ignore the flag" do
      visit("/review")

      expect(page).to have_selector(".reviewable-actions .chat-message-ignore")
    end
  end
end
