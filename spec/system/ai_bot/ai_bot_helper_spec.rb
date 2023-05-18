# frozen_string_literal: true
RSpec.describe "AI chat channel summarization", type: :system, js: true do
  fab!(:user) { Fabricate(:admin) }

  before do
    sign_in(user)
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_enabled_chat_bots = "gpt-4|gpt-3.5-turbo"
  end

  it "shows the AI bot button, which is clickable" do
    visit "/latest"
    expect(page).to have_selector(".ai-bot-button")
    find(".ai-bot-button").click

    expect(page).to have_selector(".ai-bot-available-bot-content")
    find("button.ai-bot-available-bot-content:first-child").click

    # composer is open
    expect(page).to have_selector(".d-editor-container")
  end
end
