# frozen_string_literal: true

RSpec.describe "AI Composer helper", type: :system, js: true do
  let(:search_page) { PageObjects::Pages::Search.new }
  let(:query) { "apple_pie" }
  let(:hypothetical_post) { "This is an hypothetical post generated from the keyword apple_pie" }

  fab!(:user) { Fabricate(:admin) }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:post) { Fabricate(:post, topic: topic, raw: "Apple pie is a delicious dessert to eat") }

  before do
    SiteSetting.ai_embeddings_discourse_service_api_endpoint = "http://test.com"
    prompt = DiscourseAi::Embeddings::HydeGenerators::OpenAi.new.prompt(query)
    OpenAiCompletionsInferenceStubs.stub_response(
      prompt,
      hypothetical_post,
      req_opts: {
        max_tokens: 400,
      },
    )

    hyde_embedding = [0.049382, 0.9999]
    EmbeddingsGenerationStubs.discourse_service(
      SiteSetting.ai_embeddings_model,
      hypothetical_post,
      hyde_embedding,
    )

    SearchIndexer.enable
    SearchIndexer.index(topic, force: true)
    SiteSetting.ai_embeddings_semantic_search_enabled = true
    sign_in(user)
  end

  after do
    described_class.clear_cache_for(query)
    SearchIndexer.disable
  end

  describe "when performing a search in the full page search page" do
    skip "TODO: Implement test after doing LLM abrstraction" do
      it "performs AI search in the background and hides results by default" do
        visit("/search?expanded=true")
        search_page.type_in_search("apple pie")
        search_page.click_search_button
      end
    end
  end
end
