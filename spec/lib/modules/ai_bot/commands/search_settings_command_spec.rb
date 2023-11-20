#frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Commands::SearchSettingsCommand do
  let(:search) { described_class.new(bot: nil, args: nil) }

  describe "#process" do
    it "can handle no results" do
      results = search.process(query: "this will not exist frogs")
      expect(results[:args]).to eq({ query: "this will not exist frogs" })
      expect(results[:rows]).to eq([])
    end

    it "can return more many settings with no descriptions if there are lots of hits" do
      results = search.process(query: "a")

      expect(results[:rows].length).to be > 30
      expect(results[:rows][0].length).to eq(1)
    end

    it "can return descriptions if there are few matches" do
      results =
        search.process(query: "this will not be found!@,default_locale,ai_bot_enabled_chat_bots")

      expect(results[:rows].length).to eq(2)

      expect(results[:rows][0][1]).not_to eq(nil)
    end
  end
end
