# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::Discord::Bot::Search do
  let(:interaction_body) do
    { data: { options: [{ value: "test query" }] }, token: "interaction_token" }.to_json
  end
  let(:search) { described_class.new(interaction_body) }

  describe "#handle_interaction!" do
    it "creates a reply with search results" do
      allow_any_instance_of(DiscourseAi::AiBot::Tools::Search).to receive(:invoke).and_return(
        { rows: [%w[Title /link]] },
      )
      expect(search).to receive(:create_reply).with(/Here are the top search results/)
      search.handle_interaction!
    end
  end
end
