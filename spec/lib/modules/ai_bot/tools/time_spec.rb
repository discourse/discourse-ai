#frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Tools::Time do
  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("open_ai:gpt-3.5-turbo") }

  before { SiteSetting.ai_bot_enabled = true }

  describe "#process" do
    it "can generate correct info" do
      freeze_time

      args = { timezone: "America/Los_Angeles" }
      info = described_class.new(args, bot_user: bot_user, llm: llm).invoke

      expect(info).to eq({ args: args, time: Time.now.in_time_zone("America/Los_Angeles").to_s })
      expect(info.to_s).not_to include("not_here")
    end
  end
end
