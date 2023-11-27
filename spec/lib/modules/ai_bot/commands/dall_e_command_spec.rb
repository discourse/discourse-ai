#frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Commands::DallECommand do
  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }
  let(:bot) { DiscourseAi::AiBot::OpenAiBot.new(bot_user) }

  before { SiteSetting.ai_bot_enabled = true }

  describe "#process" do
    it "can generate correct info with azure" do
      post = Fabricate(:post)

      SiteSetting.ai_openai_api_key = "abc"
      SiteSetting.ai_openai_dall_e_3_url = "https://test.azure.com/some_url"

      image =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="

      data = [{ b64_json: image, revised_prompt: "a pink cow 1" }]
      prompts = ["a pink cow", "a red cow"]

      WebMock
        .stub_request(:post, SiteSetting.ai_openai_dall_e_3_url)
        .with do |request|
          json = JSON.parse(request.body, symbolize_names: true)

          expect(prompts).to include(json[:prompt])
          expect(request.headers["Api-Key"]).to eq("abc")
          true
        end
        .to_return(status: 200, body: { data: data }.to_json)

      image = described_class.new(bot: bot, post: post, args: nil)

      info = image.process(prompts: prompts).to_json

      expect(JSON.parse(info)).to eq("prompts" => ["a pink cow 1", "a pink cow 1"])
      expect(image.custom_raw).to include("upload://")
      expect(image.custom_raw).to include("[grid]")
      expect(image.custom_raw).to include("a pink cow 1")
    end

    it "can generate correct info" do
      post = Fabricate(:post)

      SiteSetting.ai_openai_api_key = "abc"

      image =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="

      data = [{ b64_json: image, revised_prompt: "a pink cow 1" }]
      prompts = ["a pink cow", "a red cow"]

      WebMock
        .stub_request(:post, "https://api.openai.com/v1/images/generations")
        .with do |request|
          json = JSON.parse(request.body, symbolize_names: true)
          expect(prompts).to include(json[:prompt])
          true
        end
        .to_return(status: 200, body: { data: data }.to_json)

      image = described_class.new(bot: bot, post: post, args: nil)

      info = image.process(prompts: prompts).to_json

      expect(JSON.parse(info)).to eq("prompts" => ["a pink cow 1", "a pink cow 1"])
      expect(image.custom_raw).to include("upload://")
      expect(image.custom_raw).to include("[grid]")
      expect(image.custom_raw).to include("a pink cow 1")
    end
  end
end
