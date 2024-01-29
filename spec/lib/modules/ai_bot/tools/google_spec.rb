#frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Tools::Google do
  subject(:search) { described_class.new({ query: "some search term" }) }

  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("open_ai:gpt-3.5-turbo") }
  let(:progress_blk) { Proc.new {} }

  before { SiteSetting.ai_bot_enabled = true }

  describe "#process" do
    it "will not explode if there are no results" do
      post = Fabricate(:post)

      SiteSetting.ai_google_custom_search_api_key = "abc"
      SiteSetting.ai_google_custom_search_cx = "cx"

      json_text = { searchInformation: { totalResults: "0" } }.to_json

      stub_request(
        :get,
        "https://www.googleapis.com/customsearch/v1?cx=cx&key=abc&num=10&q=some%20search%20term",
      ).to_return(status: 200, body: json_text, headers: {})

      info = search.invoke(bot_user, llm, &progress_blk).to_json

      expect(search.results_count).to eq(0)
      expect(info).to_not include("oops")
    end

    it "can generate correct info" do
      post = Fabricate(:post)

      SiteSetting.ai_google_custom_search_api_key = "abc"
      SiteSetting.ai_google_custom_search_cx = "cx"

      json_text = {
        searchInformation: {
          totalResults: "2",
        },
        items: [
          {
            title: "title1",
            link: "link1",
            snippet: "snippet1",
            displayLink: "displayLink1",
            formattedUrl: "formattedUrl1",
            oops: "do no include me ... oops",
          },
          {
            title: "title2",
            link: "link2",
            displayLink: "displayLink1",
            formattedUrl: "formattedUrl1",
            oops: "do no include me ... oops",
          },
        ],
      }.to_json

      stub_request(
        :get,
        "https://www.googleapis.com/customsearch/v1?cx=cx&key=abc&num=10&q=some%20search%20term",
      ).to_return(status: 200, body: json_text, headers: {})

      info = search.invoke(bot_user, llm, &progress_blk).to_json

      expect(search.results_count).to eq(2)
      expect(info).to include("title1")
      expect(info).to include("snippet1")
      expect(info).to include("some+search+term")
      expect(info).to include("title2")
      expect(info).to_not include("oops")
    end
  end
end
