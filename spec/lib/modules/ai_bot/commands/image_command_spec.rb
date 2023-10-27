#frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Commands::ImageCommand do
  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }

  before { SiteSetting.ai_bot_enabled = true }

  describe "#process" do
    it "can generate correct info" do
      post = Fabricate(:post)

      SiteSetting.ai_stability_api_url = "https://api.stability.dev"
      SiteSetting.ai_stability_api_key = "abc"

      image =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="

      artifacts = [{ base64: image, seed: 99 }]
      prompts = ["a pink cow", "a red cow"]

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

      image = described_class.new(bot_user: bot_user, post: post, args: nil)

      info = image.process(prompts: prompts).to_json

      expect(JSON.parse(info)).to eq(
        "prompts" => [
          { "prompt" => "a pink cow", "seed" => 99 },
          { "prompt" => "a red cow", "seed" => 99 },
        ],
        "displayed_to_user" => true,
      )
      expect(image.custom_raw).to include("upload://")
      expect(image.custom_raw).to include("[grid]")
      expect(image.custom_raw).to include("a pink cow")
      expect(image.custom_raw).to include("a red cow")
    end
  end
end
