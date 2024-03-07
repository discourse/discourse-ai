# frozen_string_literal: true
RSpec.describe "AI chat channel summarization", type: :system, js: true do
  fab!(:user)
  fab!(:group) { Fabricate(:group, visibility_level: Group.visibility_levels[:staff]) }

  before do
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_enabled_chat_bots = "gpt-4|gpt-3.5-turbo"
    SiteSetting.ai_bot_allowed_groups = group.id.to_s
    sign_in(user)
  end

  it "does not show AI button to users not in group" do
    visit "/latest"
    expect(page).not_to have_selector(".ai-bot-button")
  end

  it "shows the AI bot button, which is clickable (even if group is hidden)" do
    group.add(user)
    group.save

    visit "/latest"
    expect(page).to have_selector(".ai-bot-button")
    find(".ai-bot-button").click

    expect(page).to have_selector(".ai-bot-available-bot-content")
    find("button.ai-bot-available-bot-content:first-child").click

    # composer is open
    expect(page).to have_selector(".d-editor-container")

    SiteSetting.ai_bot_add_to_header = false
    visit "/latest"
    expect(page).not_to have_selector(".ai-bot-button")
  end
end
