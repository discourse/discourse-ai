#frozen_string_literal: true

require_relative "../../../../support/openai_completions_inference_stubs"

RSpec.describe DiscourseAi::AiBot::Commands::SearchCommand do
  fab!(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }

  before { SearchIndexer.enable }
  after { SearchIndexer.disable }

  describe "#process" do
    it "can handle limits" do
      post1 = Fabricate(:post)
      _post2 = Fabricate(:post, user: post1.user)
      _post3 = Fabricate(:post, user: post1.user)

      # search has no built in support for limit: so handle it from the outside
      search = described_class.new(bot_user, post1)

      results = search.process("@#{post1.user.username} limit:2")

      # title + 2 rows
      expect(results.split("\n").length).to eq(3)
    end
  end
end
