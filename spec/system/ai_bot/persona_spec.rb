# frozen_string_literal: true

RSpec.describe "AI personas", type: :system, js: true do
  fab!(:admin)
  fab!(:gpt_4) { Fabricate(:llm_model, name: "gpt-4") }

  before do
    SiteSetting.ai_bot_enabled = true
    toggle_enabled_bots(bots: [gpt_4])
    sign_in(admin)
  end

  it "remembers the last selected persona" do
    visit "/"
    find(".d-header .ai-bot-button").click()
    persona_selector =
      PageObjects::Components::SelectKit.new(".persona-llm-selector__persona-dropdown")

    id = DiscourseAi::Personas::Persona.all(user: admin).first.id

    expect(persona_selector).to have_selected_value(id)

    persona_selector.expand
    persona_selector.select_row_by_value(-2)

    visit "/"
    find(".d-header .ai-bot-button").click()
    persona_selector =
      PageObjects::Components::SelectKit.new(".persona-llm-selector__persona-dropdown")
    persona_selector.expand
    expect(persona_selector).to have_selected_value(-2)
  end
end
