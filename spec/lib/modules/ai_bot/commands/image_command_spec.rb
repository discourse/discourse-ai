#frozen_string_literal: true

require_relative "../../../../support/stable_difussion_stubs"

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

      StableDiffusionStubs.new.stub_response("a pink cow", [image, image])

      image = described_class.new(bot_user: bot_user, post: post, args: nil)

      info = image.process(prompt: "a pink cow").to_json

      expect(JSON.parse(info)).to eq("prompt" => "a pink cow", "displayed_to_user" => true)
      expect(image.custom_raw).to include("upload://")
      expect(image.custom_raw).to include("[grid]")
      expect(image.custom_raw).to include("a pink cow")
    end
  end
end
