# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Tools::WebBrowser do
  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("open_ai:gpt-4-turbo") }

  before do
    SiteSetting.ai_openai_api_key = "asd"
    SiteSetting.ai_bot_enabled = true
  end

  describe "#invoke" do
    it "can retrieve the content of a webpage" do
      url = "https://arxiv.org/html/2403.17011v1"

      tool = described_class.new({ url: url })
      result = tool.invoke(bot_user, llm)

      # write me...
    end
  end
end
