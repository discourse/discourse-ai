#frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Tools::DbSchema do
  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("gpt-3.5-turbo") }

  before { SiteSetting.ai_bot_enabled = true }
  describe "#process" do
    it "returns rich schema for tables" do
      result = described_class.new({ tables: "posts,topics" }).invoke(bot_user, llm)

      expect(result[:schema_info]).to include("raw text")
      expect(result[:schema_info]).to include("views integer")
      expect(result[:schema_info]).to include("posts")
      expect(result[:schema_info]).to include("topics")

      expect(result[:tables]).to eq("posts,topics")
    end
  end
end
