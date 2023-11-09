# frozen_string_literal: true

RSpec.describe "AI Composer helper", type: :system, js: true do
  let(:search_page) { PageObjects::Pages::Search.new }
  fab!(:user) { Fabricate(:admin) }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:post) { Fabricate(:post, topic: topic, raw: "Apple pie is a delicious dessert to eat") }


  before do
    SearchIndexer.enable
    SearchIndexer.index(topic, force: true)
    SiteSetting.ai_embeddings_semantic_search_enabled = true
    sign_in(user)
  end

  after { SearchIndexer.disable }


  describe "when performing a search in the full page search page" do
    it "performs AI search in the background and hides results by default" do
      visit("/search?expanded=true")
      search_page.type_in_search("apple pie")
      search_page.click_search_button
      # TODO: Allow semantic search to be performed correctly in spec.
    end
  end
end
