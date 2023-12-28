#frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Tools::Image do
  subject(:tool) { described_class.new({ prompts: prompts, seeds: [99, 32] }) }

  let(:llm) { DiscourseAi::Completions::Llm.proxy("gpt-3.5-turbo") }
  let(:progress_blk) { Proc.new {} }

  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }

  let(:prompts) { ["a pink cow", "a red cow"] }

  before { SiteSetting.ai_bot_enabled = true }

  describe "#process" do
    it "can generate correct info" do
      post = Fabricate(:post)

      SiteSetting.ai_stability_api_url = "https://api.stability.dev"
      SiteSetting.ai_stability_api_key = "abc"

      image =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="

      artifacts = [{ base64: image, seed: 99 }]

      WebMock
        .stub_request(
          :post,
          "https://api.stability.dev/v1/generation/#{SiteSetting.ai_stability_engine}/text-to-image",
        )
        .with do |request|
          json = JSON.parse(request.body, symbolize_names: true)
          expect(prompts).to include(json[:text_prompts][0][:text])
          true
        end
        .to_return(status: 200, body: { artifacts: artifacts }.to_json)

      info = tool.invoke(bot_user, llm, &progress_blk).to_json

      expect(JSON.parse(info)).to eq("prompts" => ["a pink cow", "a red cow"], "seeds" => [99, 99])
      expect(tool.custom_raw).to include("upload://")
      expect(tool.custom_raw).to include("[grid]")
      expect(tool.custom_raw).to include("a pink cow")
      expect(tool.custom_raw).to include("a red cow")
    end
  end
end
