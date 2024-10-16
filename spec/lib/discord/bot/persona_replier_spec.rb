# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::Discord::Bot::PersonaReplier do
  let(:interaction_body) do
    { data: { options: [{ value: "test query" }] }, token: "interaction_token" }.to_json.to_s
  end
  let(:persona_replier) { described_class.new(interaction_body) }

  before do
    SiteSetting.ai_discord_search_persona = "-1"
    allow_any_instance_of(DiscourseAi::AiBot::Bot).to receive(:reply).and_return(
      "This is a reply from bot!",
    )
    allow(persona_replier).to receive(:create_reply)
  end

  describe "#handle_interaction!" do
    it "creates and updates replies" do
      persona_replier.handle_interaction!
      expect(persona_replier).to have_received(:create_reply).at_least(:once)
    end
  end
end
