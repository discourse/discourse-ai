# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::Admin::AiSpamController do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }

  fab!(:llm_model)

  describe "#show" do
    context "when logged in as admin" do
      before do
        sign_in(admin)
      end

      it "returns the serialized spam settings" do
        SiteSetting.ai_spam_detection_enabled = true
        SiteSetting.ai_spam_detection_custom_instructions = "Be strict with spam"
        SiteSetting.ai_spam_detection_model = llm_model.identifier

        get "/admin/plugins/discourse-ai/ai-spam.json"

        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["is_enabled"]).to eq(true)
        expect(json["selected_llm"]).to eq(llm_model.identifier)
        expect(json["custom_instructions"]).to eq("Be strict with spam")
        expect(json["available_llms"]).to be_an(Array)
        expect(json["stats"]).to be_present
      end

      it "includes the correct stats structure" do
        get "/admin/plugins/discourse-ai/ai-spam.json"

        json = response.parsed_body
        expect(json["stats"]).to include(
          "scanned_count",
          "spam_detected",
          "false_positives",
          "false_negatives"
        )
      end
    end

    context "when not logged in as admin" do
      it "returns 404 for anonymous users" do
        get "/admin/plugins/discourse-ai/ai-spam.json"
        expect(response.status).to eq(404)
      end

      it "returns 404 for regular users" do
        sign_in(user)
        get "/admin/plugins/discourse-ai/ai-spam.json"
        expect(response.status).to eq(404)
      end
    end

    context "when plugin is disabled" do
      before do
        sign_in(admin)
        SiteSetting.discourse_ai_enabled = false
      end

      it "returns 404" do
        get "/admin/plugins/discourse-ai/ai-spam.json"
        expect(response.status).to eq(404)
      end
    end
  end
end
