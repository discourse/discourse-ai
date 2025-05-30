# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiFeaturesController do
  let(:controller) { described_class.new }
  fab!(:admin)
  fab!(:group)
  fab!(:llm_model)
  fab!(:summarizer_agent) { Fabricate(:ai_agent) }
  fab!(:alternate_summarizer_agent) { Fabricate(:ai_agent) }

  before do
    sign_in(admin)
    SiteSetting.ai_bot_enabled = true
    SiteSetting.discourse_ai_enabled = true
  end

  describe "#index" do
    it "lists all features backed by agents" do
      get "/admin/plugins/discourse-ai/ai-features.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["ai_features"].count).to eq(4)
    end
  end

  describe "#edit" do
    it "returns a success response" do
      get "/admin/plugins/discourse-ai/ai-features/1/edit.json"
      expect(response.parsed_body["name"]).to eq(I18n.t "discourse_ai.features.summarization.name")
    end
  end
end
