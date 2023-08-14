#frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Commands::ImageCommand do
  fab!(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }

  describe "#process" do
    it "can generate correct info" do
      post = Fabricate(:post)

      SiteSetting.ai_stability_api_url = "https://api.stability.dev"
      SiteSetting.ai_stability_api_key = "abc"

      image =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="

      stub_request(
        :post,
        "https://api.stability.dev/v1/generation/#{SiteSetting.ai_stability_engine}/text-to-image",
      )
        .with do |request|
          json = JSON.parse(request.body)
          expect(json["text_prompts"][0]["text"]).to eq("a pink cow")
          true
        end
        .to_return(status: 200, body: { artifacts: [{ base64: image }, { base64: image }] }.to_json)

      image = described_class.new(bot_user: bot_user, post: post, args: nil)

      info = image.process(prompt: "a pink cow").to_json

      expect(JSON.parse(info)).to eq("prompt" => "a pink cow", "displayed_to_user" => true)
      expect(image.custom_raw).to include("upload://")
      expect(image.custom_raw).to include("[grid]")
      expect(image.custom_raw).to include("a pink cow")
    end
  end
end
