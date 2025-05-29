# frozen_string_literal: true

RSpec.describe "AI agents", type: :system, js: true do
  fab!(:admin)
  fab!(:gpt_4) { Fabricate(:llm_model, name: "gpt-4") }

  before do
    SiteSetting.ai_bot_enabled = true
    toggle_enabled_bots(bots: [gpt_4])
    sign_in(admin)
  end

  it "remembers the last selected agent" do
    visit "/"
    find(".d-header .ai-bot-button").click()
    agent_selector =
      PageObjects::Components::SelectKit.new(".agent-llm-selector__agent-dropdown")

    id = DiscourseAi::Agents::Agent.all(user: admin).first.id

    expect(agent_selector).to have_selected_value(id)

    agent_selector.expand
    agent_selector.select_row_by_value(-2)

    visit "/"
    find(".d-header .ai-bot-button").click()
    agent_selector =
      PageObjects::Components::SelectKit.new(".agent-llm-selector__agent-dropdown")
    agent_selector.expand
    expect(agent_selector).to have_selected_value(-2)
  end
end
