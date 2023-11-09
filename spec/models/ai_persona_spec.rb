# frozen_string_literal: true

RSpec.describe AiPersona do
  it "does not leak caches between sites" do
    AiPersona.create!(
      name: "pun_bot",
      description: "you write puns",
      system_prompt: "you are pun bot",
      commands: ["ImageCommand"],
      allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
    )

    AiPersona.all_personas

    expect(AiPersona.persona_cache[:value].length).to eq(1)
    RailsMultisite::ConnectionManagement.stubs(:current_db) { "abc" }
    expect(AiPersona.persona_cache[:value]).to eq(nil)
  end
end
