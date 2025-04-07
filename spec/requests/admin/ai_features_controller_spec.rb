# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiFeaturesController do
  let(:controller) { described_class.new }
  fab!(:admin)
  fab!(:group)
  fab!(:llm_model)
  fab!(:summarizer_persona) { Fabricate(:ai_persona) }
  fab!(:alternate_summarizer_persona) { Fabricate(:ai_persona) }

  before do
    sign_in(admin)
    SiteSetting.ai_bot_enabled = true
    SiteSetting.discourse_ai_enabled = true
  end

  describe "#index" do
    it "lists all features backed by personas" do
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

  describe "#update" do
    before do
      SiteSetting.ai_summarization_persona = summarizer_persona.id
      SiteSetting.ai_summarization_enabled = true
    end

    it "updates the feature" do
      expect(SiteSetting.ai_summarization_persona).to eq(summarizer_persona.id.to_s)
      expect(SiteSetting.ai_summarization_enabled).to eq(true)

      put "/admin/plugins/discourse-ai/ai-features/1.json",
          params: {
            ai_feature: {
              enabled: false,
              persona_id: alternate_summarizer_persona.id,
            },
          }

      expect(SiteSetting.ai_summarization_persona).to eq(alternate_summarizer_persona.id.to_s)
      expect(SiteSetting.ai_summarization_enabled).to eq(false)
    end
  end
end
