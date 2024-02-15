# frozen_string_literal: true
RSpec.describe "AI personas", type: :system, js: true do
  fab!(:admin)

  before do
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_enabled_chat_bots = "gpt-4"
    sign_in(admin)

    Group.refresh_automatic_groups!
  end

  it "remembers the last selected persona" do
    visit "/"
    find(".d-header .ai-bot-button").click()
    persona_selector = PageObjects::Components::SelectKit.new(".persona-selector__dropdown")

    id = DiscourseAi::AiBot::Personas::Persona.all(user: admin).first.id

    expect(persona_selector).to have_selected_value(id)

    persona_selector.expand
    persona_selector.select_row_by_value(-2)

    visit "/"
    find(".d-header .ai-bot-button").click()
    persona_selector = PageObjects::Components::SelectKit.new(".persona-selector__dropdown")
    persona_selector.expand
    expect(persona_selector).to have_selected_value(-2)
  end

  it "allows creation of a persona" do
    visit "/admin/plugins/discourse-ai/ai-personas"
    find(".ai-persona-list-editor__header .btn-primary").click()
    find(".ai-persona-editor__name").set("Test Persona")
    find(".ai-persona-editor__description").fill_in(with: "I am a test persona")
    find(".ai-persona-editor__system_prompt").fill_in(with: "You are a helpful bot")

    command_selector = PageObjects::Components::SelectKit.new(".ai-persona-editor__commands")
    command_selector.expand
    command_selector.select_row_by_value("Read")

    find(".ai-persona-editor__save").click()

    expect(page).not_to have_current_path("/admin/plugins/discourse-ai/ai-personas/new")

    persona_id = page.current_path.split("/").last.to_i

    persona = AiPersona.find(persona_id)
    expect(persona.name).to eq("Test Persona")
    expect(persona.description).to eq("I am a test persona")
    expect(persona.system_prompt).to eq("You are a helpful bot")
    expect(persona.commands).to eq(["Read"])
  end

  it "will not allow deletion or editing of system personas" do
    visit "/admin/plugins/discourse-ai/ai-personas/#{DiscourseAi::AiBot::Personas::Persona.system_personas.values.first}"
    expect(page).not_to have_selector(".ai-persona-editor__delete")
    expect(find(".ai-persona-editor__system_prompt")).to be_disabled
  end

  it "will enable persona right away when you click on enable but does not save side effects" do
    persona = Fabricate(:ai_persona, enabled: false)

    visit "/admin/plugins/discourse-ai/ai-personas/#{persona.id}"

    find(".ai-persona-editor__name").set("Test Persona 1")
    PageObjects::Components::DToggleSwitch.new(".ai-persona-editor__enabled").toggle

    try_until_success { expect(persona.reload.enabled).to eq(true) }

    persona.reload
    expect(persona.enabled).to eq(true)
    expect(persona.name).not_to eq("Test Persona 1")
  end
end
