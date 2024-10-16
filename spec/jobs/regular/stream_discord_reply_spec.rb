# frozen_string_literal: true

require "rails_helper"

RSpec.describe Jobs::StreamDiscordReply, type: :job do
  let(:interaction) do
    {
      type: 2,
      data: {
        options: [{ value: "test query" }],
      },
      token: "interaction_token",
    }.to_json.to_s
  end

  before do
    SiteSetting.ai_discord_search_mode = "persona"
    SiteSetting.ai_discord_search_persona = -1
  end

  it "calls PersonaReplier when search mode is persona" do
    expect_any_instance_of(DiscourseAi::Discord::Bot::PersonaReplier).to receive(
      :handle_interaction!,
    )
    described_class.new.execute(interaction: interaction)
  end

  it "calls Search when search mode is not persona" do
    SiteSetting.ai_discord_search_mode = "search"
    expect_any_instance_of(DiscourseAi::Discord::Bot::Search).to receive(:handle_interaction!)
    described_class.new.execute(interaction: interaction)
  end
end
