# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::SettingsExplorer do
  let :settings_explorer do
    subject
  end

  it "renders schema" do
    prompt = settings_explorer.system_prompt

    # check we do not render plugin settings
    expect(prompt).not_to include("ai_bot_enabled_agents")

    expect(prompt).to include("site_description")

    expect(settings_explorer.tools).to eq(
      [DiscourseAi::Agents::Tools::SettingContext, DiscourseAi::Agents::Tools::SearchSettings],
    )
  end
end
