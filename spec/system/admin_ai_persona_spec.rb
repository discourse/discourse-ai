# frozen_string_literal: true

RSpec.describe "Admin AI persona configuration", type: :system, js: true do
  fab!(:admin)

  before do
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_enabled_chat_bots = "gpt-4"
    sign_in(admin)
  end

  it "allows creation of a persona" do
    visit "/admin/plugins/discourse-ai/ai-personas"
    find(".ai-persona-list-editor__header .btn-primary").click()
    find(".ai-persona-editor__name").set("Test Persona")
    find(".ai-persona-editor__description").fill_in(with: "I am a test persona")
    find(".ai-persona-editor__system_prompt").fill_in(with: "You are a helpful bot")

    tool_selector = PageObjects::Components::SelectKit.new(".ai-persona-editor__tools")
    tool_selector.expand
    tool_selector.select_row_by_value("Read")

    find(".ai-persona-editor__save").click()

    expect(page).not_to have_current_path("/admin/plugins/discourse-ai/ai-personas/new")

    persona_id = page.current_path.split("/").last.to_i

    persona = AiPersona.find(persona_id)
    expect(persona.name).to eq("Test Persona")
    expect(persona.description).to eq("I am a test persona")
    expect(persona.system_prompt).to eq("You are a helpful bot")
    expect(persona.tools).to eq([["Read", { "read_private" => nil }]])
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

  it "can navigate the AI plugin with breadcrumbs" do
    visit "/admin/plugins/discourse-ai/ai-personas"
    expect(page).to have_css(".d-breadcrumbs")
    expect(page).to have_css(".d-breadcrumbs__item", count: 4)
    find(".d-breadcrumbs__item", text: I18n.t("admin_js.admin.plugins.title")).click
    expect(page).to have_current_path("/admin/plugins")
  end
end
