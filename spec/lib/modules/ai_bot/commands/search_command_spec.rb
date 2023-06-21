#frozen_string_literal: true

require_relative "../../../../support/openai_completions_inference_stubs"

RSpec.describe DiscourseAi::AiBot::Commands::SearchCommand do
  fab!(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }

  before { SearchIndexer.enable }
  after { SearchIndexer.disable }

  describe "#process" do
    it "can handle no results" do
      post1 = Fabricate(:post)
      search = described_class.new(bot_user, post1)

      results = search.process({ query: "order:fake ABDDCDCEDGDG" }.to_json)
      expect(results[:args]).to eq("{\"query\":\"order:fake ABDDCDCEDGDG\"}")
      expect(results[:rows]).to eq([])
    end

    it "supports subfolder properly" do
      Discourse.stubs(:base_path).returns("/subfolder")

      post1 = Fabricate(:post)

      search = described_class.new(bot_user, post1)

      results = search.process({ limit: 1, user: post1.user.username }.to_json)
      expect(results[:rows].to_s).to include("/subfolder" + post1.url)
    end

    it "can handle limits" do
      post1 = Fabricate(:post)
      _post2 = Fabricate(:post, user: post1.user)
      _post3 = Fabricate(:post, user: post1.user)

      # search has no built in support for limit: so handle it from the outside
      search = described_class.new(bot_user, post1)

      results = search.process({ limit: 2, user: post1.user.username }.to_json)

      expect(results[:column_names].length).to eq(4)
      expect(results[:rows].length).to eq(2)

      # just searching for everything
      results = search.process({ order: "latest_topic" }.to_json)
      expect(results[:rows].length).to be > 1
    end
  end
end
