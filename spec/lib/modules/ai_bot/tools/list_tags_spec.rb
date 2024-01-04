#frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Tools::ListTags do
  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("gpt-3.5-turbo") }

  before do
    SiteSetting.ai_bot_enabled = true
    SiteSetting.tagging_enabled = true
  end

  describe "#process" do
    it "can generate correct info" do
      Fabricate(:tag, name: "america", public_topic_count: 100)
      Fabricate(:tag, name: "not_here", public_topic_count: 0)

      info = described_class.new({}).invoke(bot_user, llm)

      expect(info.to_s).to include("america")
      expect(info.to_s).not_to include("not_here")
    end
  end
end
