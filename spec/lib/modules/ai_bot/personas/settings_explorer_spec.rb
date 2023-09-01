# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Personas::SettingsExplorer do
  let :settings_explorer do
    subject
  end

  it "renders schema" do
    prompt = settings_explorer.render_system_prompt

    # check we do not render plugin settings
    expect(prompt).not_to include("ai_bot_enabled_personas")

    expect(prompt).to include("site_description")

    expect(settings_explorer.available_commands).to eq(
      [
        DiscourseAi::AiBot::Commands::SettingContextCommand,
        DiscourseAi::AiBot::Commands::SearchSettingsCommand,
      ],
    )
  end
end
