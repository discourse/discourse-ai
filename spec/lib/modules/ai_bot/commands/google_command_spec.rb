#frozen_string_literal: true

require_relative "../../../../support/openai_completions_inference_stubs"

RSpec.describe DiscourseAi::AiBot::Commands::GoogleCommand do
  fab!(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }

  describe "#process" do
    it "can generate correct info" do
      post = Fabricate(:post)

      SiteSetting.ai_google_custom_search_api_key = "abc"
      SiteSetting.ai_google_custom_search_cx = "cx"

      json_text = {
        searchInformation: {
          totalResults: "1",
        },
        items: [
          {
            title: "title1",
            link: "link1",
            snippet: "snippet1",
            displayLink: "displayLink1",
            formattedUrl: "formattedUrl1",
          },
        ],
      }.to_json

      stub_request(
        :get,
        "https://www.googleapis.com/customsearch/v1?cx=cx&key=abc&num=10&q=some%20search%20term",
      ).to_return(status: 200, body: json_text, headers: {})

      google = described_class.new(bot_user, post)
      info = google.process(query: "some search term").to_json

      expect(google.description_args[:count]).to eq(1)
      expect(info).to include("title1")
      expect(info).to include("snippet1")
    end
  end
end
