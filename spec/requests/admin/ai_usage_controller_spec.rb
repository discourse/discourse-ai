# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::Admin::AiUsageController do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }
  let(:usage_path) { "/admin/plugins/discourse-ai/ai-usage.json" }

  before { SiteSetting.discourse_ai_enabled = true }

  context "when logged in as admin" do
    before { sign_in(admin) }

    describe "#show" do
      fab!(:log1) do
        AiApiAuditLog.create!(
          provider_id: 1,
          feature_name: "summarize",
          language_model: "gpt-4",
          request_tokens: 100,
          response_tokens: 50,
          created_at: 1.day.ago,
        )
      end

      fab!(:log2) do
        AiApiAuditLog.create!(
          provider_id: 1,
          feature_name: "translate",
          language_model: "gpt-3.5",
          request_tokens: 200,
          response_tokens: 100,
          created_at: 2.days.ago,
        )
      end

      it "returns correct data structure" do
        get usage_path

        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json).to have_key("data")
        expect(json).to have_key("features")
        expect(json).to have_key("models")
        expect(json).to have_key("summary")
      end

      it "respects date filters" do
        get usage_path,
            params: {
              start_date: 3.days.ago.to_date,
              end_date: 1.day.ago.to_date,
            }

        json = response.parsed_body
        expect(json["summary"]["total_tokens"]).to eq(450) # sum of all tokens
      end

      it "filters by feature" do
        get usage_path, params: { feature: "summarize" }

        json = response.parsed_body

        features = json["features"]
        expect(features.length).to eq(1)
        expect(features.first["feature_name"]).to eq("summarize")
        expect(features.first["total_tokens"]).to eq(150)
      end

      it "filters by model" do
        get usage_path, params: { model: "gpt-3.5" }

        json = response.parsed_body
        models = json["models"]
        expect(models.length).to eq(1)
        expect(models.first["llm"]).to eq("gpt-3.5")
        expect(models.first["total_tokens"]).to eq(300)
      end

      it "handles different period groupings" do
        get usage_path, params: { period: "hour" }
        expect(response.status).to eq(200)

        get usage_path, params: { period: "month" }
        expect(response.status).to eq(200)
      end
    end
  end

  context "when not admin" do
    before { sign_in(user) }

    it "blocks access" do
      get usage_path
      expect(response.status).to eq(404)
    end
  end

  context "when plugin disabled" do
    before do
      SiteSetting.discourse_ai_enabled = false
      sign_in(admin)
    end

    it "returns error" do
      get usage_path
      expect(response.status).to eq(404)
    end
  end
end
