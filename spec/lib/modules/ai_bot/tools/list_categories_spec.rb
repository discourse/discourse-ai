# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Tools::ListCategories do
  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("open_ai:gpt-3.5-turbo") }

  before { SiteSetting.ai_bot_enabled = true }

  describe "#process" do
    it "list available categories" do
      Fabricate(:category, name: "america", posts_year: 999)

      info = described_class.new({}, bot_user: bot_user, llm: llm).invoke.to_s

      expect(info).to include("america")
      expect(info).to include("999")
    end
  end
end
