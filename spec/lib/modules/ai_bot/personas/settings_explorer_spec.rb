# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Personas::SettingsExplorer do
  let :settings_explorer do
    subject
  end

  it "renders schema" do
    prompt = settings_explorer.render_system_prompt
    # check we render settings
    expect(prompt).to include("ai_bot_enabled_personas")

    expect(settings_explorer.available_commands).to eq(
      [DiscourseAi::AiBot::Commands::SettingContextCommand],
    )
  end
end
