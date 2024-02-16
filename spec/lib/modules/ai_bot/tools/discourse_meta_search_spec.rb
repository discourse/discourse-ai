# frozen_string_literal: true
RSpec.describe DiscourseAi::AiBot::Tools::DiscourseMetaSearch do
  before do
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_openai_api_key = "asd"
  end

  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("open_ai:gpt-3.5-turbo") }
  let(:progress_blk) { Proc.new {} }

  let(:mock_search_json) do
    File.read(File.expand_path("../../../../../fixtures/search_meta/search.json", __FILE__))
  end

  let(:mock_site_json) do
    File.read(File.expand_path("../../../../../fixtures/search_meta/site.json", __FILE__))
  end

  it "searches meta.discourse.org" do
    stub_request(:get, "https://meta.discourse.org/search.json?q=test").to_return(
      status: 200,
      body: mock_search_json,
      headers: {
      },
    )

    stub_request(:get, "https://meta.discourse.org/site.json").to_return(
      status: 200,
      body: mock_site_json,
      headers: {
      },
    )

    search = described_class.new({ search_query: "test" })
    results = search.invoke(bot_user, llm, &progress_blk)
    expect(results[:rows].length).to eq(20)

    expect(results[:rows].first[results[:column_names].index("category")]).to eq(
      "documentation > developers",
    )
  end
end
