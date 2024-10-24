# frozen_string_literal: true
RSpec.describe "AI chat channel summarization", type: :system, js: true do
  fab!(:user)
  fab!(:group) { Fabricate(:group, visibility_level: Group.visibility_levels[:staff]) }

  fab!(:gpt_4) { Fabricate(:llm_model, name: "gpt-4") }
  fab!(:gpt_3_5_turbo) { Fabricate(:llm_model, name: "gpt-3.5-turbo") }

  before do
    SiteSetting.ai_bot_enabled = true
    toggle_enabled_bots(bots: [gpt_4, gpt_3_5_turbo])
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

    allowed_persona = AiPersona.last
    allowed_persona.update!(allowed_group_ids: [group.id], enabled: true)

    visit "/latest"
    expect(page).to have_selector(".ai-bot-button")
    find(".ai-bot-button").click

    find(".gpt-persona").click
    expect(page).to have_css(".gpt-persona ul li", count: 1)

    find(".llm-selector").click
    expect(page).to have_css(".llm-selector ul li", count: 2)

    expect(page).to have_selector(".d-editor-container")

    # lets disable bots but still allow 1 persona
    allowed_persona.create_user!
    allowed_persona.update!(default_llm: "custom:#{gpt_4.id}")

    gpt_4.update!(enabled_chat_bot: false)
    gpt_3_5_turbo.update!(enabled_chat_bot: false)

    visit "/latest"
    find(".ai-bot-button").click

    find(".gpt-persona").click
    expect(page).to have_css(".gpt-persona ul li", count: 1)
    expect(page).not_to have_selector(".llm-selector")

    SiteSetting.ai_bot_add_to_header = false
    visit "/latest"
    expect(page).not_to have_selector(".ai-bot-button")
  end
end
