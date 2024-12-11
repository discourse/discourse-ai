# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::Admin::AiSpamController do
  fab!(:admin)
  fab!(:user)
  fab!(:llm_model)

  describe "#update" do
    context "when logged in as admin" do
      before { sign_in(admin) }

      it "can update settings from scratch" do
        put "/admin/plugins/discourse-ai/ai-spam.json",
            params: {
              is_enabled: true,
              llm_model_id: llm_model.id,
              custom_instructions: "custom instructions",
            }

        expect(response.status).to eq(200)
        expect(SiteSetting.ai_spam_detection_enabled).to eq(true)
        expect(AiModerationSetting.spam.llm_model_id).to eq(llm_model.id)
        expect(AiModerationSetting.spam.data["custom_instructions"]).to eq("custom instructions")
      end

      it "can not enable spam detection without a model selected" do
        put "/admin/plugins/discourse-ai/ai-spam.json",
            params: {
              custom_instructions: "custom instructions",
            }
        expect(response.status).to eq(422)
      end

      it "can not fiddle with custom instructions without an llm" do
        put "/admin/plugins/discourse-ai/ai-spam.json", params: { is_enabled: true }
        expect(response.status).to eq(422)
      end

      context "when spam detection was already set" do
        fab!(:setting) do
          AiModerationSetting.create(
            {
              setting_type: :spam,
              llm_model_id: llm_model.id,
              data: {
                custom_instructions: "custom instructions",
              },
            },
          )
        end

        it "can partially update settings" do
          put "/admin/plugins/discourse-ai/ai-spam.json", params: { is_enabled: false }

          expect(response.status).to eq(200)
          expect(SiteSetting.ai_spam_detection_enabled).to eq(false)
          expect(AiModerationSetting.spam.llm_model_id).to eq(llm_model.id)
          expect(AiModerationSetting.spam.data["custom_instructions"]).to eq("custom instructions")
        end

        it "can update pre existing settings" do
          put "/admin/plugins/discourse-ai/ai-spam.json",
              params: {
                is_enabled: true,
                llm_model_id: llm_model.id,
                custom_instructions: "custom instructions new",
              }

          expect(response.status).to eq(200)
          expect(SiteSetting.ai_spam_detection_enabled).to eq(true)
          expect(AiModerationSetting.spam.llm_model_id).to eq(llm_model.id)
          expect(AiModerationSetting.spam.data["custom_instructions"]).to eq(
            "custom instructions new",
          )
        end
      end
    end
  end

  describe "#show" do
    context "when logged in as admin" do
      before { sign_in(admin) }

      it "returns the serialized spam settings" do
        SiteSetting.ai_spam_detection_enabled = true

        get "/admin/plugins/discourse-ai/ai-spam.json"

        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["is_enabled"]).to eq(true)
        expect(json["selected_llm"]).to eq(nil)
        expect(json["custom_instructions"]).to eq(nil)
        expect(json["available_llms"]).to be_an(Array)
        expect(json["stats"]).to be_present
      end

      it "return proper settings when spam detection is enabled" do
        SiteSetting.ai_spam_detection_enabled = true

        AiModerationSetting.create(
          {
            setting_type: :spam,
            llm_model_id: llm_model.id,
            data: {
              custom_instructions: "custom instructions",
            },
          },
        )

        flagging_user = DiscourseAi::AiModeration::SpamScanner.flagging_user
        expect(flagging_user.id).not_to eq(Discourse.system_user.id)

        AiSpamLog.create!(post_id: 1, llm_model_id: llm_model.id, is_spam: true, payload: "test")

        get "/admin/plugins/discourse-ai/ai-spam.json"

        json = response.parsed_body
        expect(json["is_enabled"]).to eq(true)
        expect(json["llm_id"]).to eq(llm_model.id)
        expect(json["custom_instructions"]).to eq("custom instructions")

        expect(json["stats"].to_h).to eq(
          "scanned_count" => 1,
          "spam_detected" => 1,
          "false_positives" => 0,
          "false_negatives" => 0,
        )

        expect(json["flagging_username"]).to eq(flagging_user.username)
      end

      it "includes the stats" do
        expect(SpamScanner.flagging_user.id).not_to eq(SystemUser.id)
        get "/admin/plugins/discourse-ai/ai-spam.json"

        json = response.parsed_body
        expect(json["stats"]).to include(
          "scanned_count",
          "spam_detected",
          "false_positives",
          "false_negatives",
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
