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

      it "denies update for disallowed seeded llm" do
        seeded_llm = Fabricate(:llm_model, id: -1)

        put "/admin/plugins/discourse-ai/ai-spam.json",
            params: {
              is_enabled: true,
              llm_model_id: seeded_llm.id,
              custom_instructions: "custom instructions",
            }

        expect(response.status).to eq(422)

        SiteSetting.ai_spam_detection_model_allowed_seeded_models = seeded_llm.id.to_s

        put "/admin/plugins/discourse-ai/ai-spam.json",
            params: {
              is_enabled: true,
              llm_model_id: seeded_llm.id,
              custom_instructions: "custom instructions",
            }

        expect(response.status).to eq(200)
      end

      it "ensures that seeded llm ID is properly passed and allowed" do
        seeded_llm = Fabricate(:seeded_model)

        SiteSetting.ai_spam_detection_model_allowed_seeded_models = [
          llm_model.id,
          seeded_llm.id,
        ].join("|")

        put "/admin/plugins/discourse-ai/ai-spam.json",
            params: {
              is_enabled: true,
              llm_model_id: seeded_llm.id,
              custom_instructions: "custom instructions",
            }
        expect(SiteSetting.ai_spam_detection_model_allowed_seeded_models).to eq(
          "#{llm_model.id}|#{seeded_llm.id}",
        )
        expect(response.status).to eq(200)
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

  describe "#test" do
    fab!(:spam_post) { Fabricate(:post) }
    fab!(:spam_post2) { Fabricate(:post, topic: spam_post.topic, raw: "something special 123") }
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

    before { sign_in(admin) }

    it "can scan using post url (even when trashed and user deleted)" do
      User.where(id: spam_post2.user_id).delete_all
      spam_post2.topic.trash!
      spam_post2.trash!

      llm2 = Fabricate(:llm_model, name: "DiffLLM")

      DiscourseAi::Completions::Llm.with_prepared_responses(["spam", "just because"]) do
        post "/admin/plugins/discourse-ai/ai-spam/test.json",
             params: {
               post_url: spam_post2.url,
               llm_id: llm2.id,
             }
      end

      expect(response.status).to eq(200)

      parsed = response.parsed_body
      expect(parsed["log"]).to include(spam_post2.raw)
      expect(parsed["log"]).to include("DiffLLM")
    end

    it "can scan using post id" do
      DiscourseAi::Completions::Llm.with_prepared_responses(["spam", "because apples"]) do
        post "/admin/plugins/discourse-ai/ai-spam/test.json",
             params: {
               post_url: spam_post.id.to_s,
             }
      end

      expect(response.status).to eq(200)

      parsed = response.parsed_body
      expect(parsed["log"]).to include(spam_post.raw)
    end

    it "returns proper spam test results" do
      freeze_time DateTime.parse("2000-01-01")

      AiSpamLog.create!(
        post: spam_post,
        llm_model: llm_model,
        is_spam: false,
        created_at: 2.days.ago,
      )

      AiSpamLog.create!(post: spam_post, llm_model: llm_model, is_spam: true, created_at: 1.day.ago)

      DiscourseAi::Completions::Llm.with_prepared_responses(["spam", "because banana"]) do
        post "/admin/plugins/discourse-ai/ai-spam/test.json",
             params: {
               post_url: spam_post.url,
               custom_instructions: "special custom instructions",
             }
      end

      expect(response.status).to eq(200)

      parsed = response.parsed_body
      expect(parsed["log"]).to include("special custom instructions")
      expect(parsed["log"]).to include(spam_post.raw)
      expect(parsed["is_spam"]).to eq(true)
      expect(parsed["log"]).to include("Scan History:")
      expect(parsed["log"]).to include("banana")
    end
  end

  describe "#show" do
    context "when logged in as admin" do
      before { sign_in(admin) }

      it "correctly filters seeded llms" do
        SiteSetting.ai_spam_detection_enabled = true
        seeded_llm = Fabricate(:seeded_model)

        get "/admin/plugins/discourse-ai/ai-spam.json"
        expect(response.status).to eq(200)
        json = response.parsed_body

        # only includes fabricated model
        expect(json["available_llms"].length).to eq(1)

        SiteSetting.ai_spam_detection_model_allowed_seeded_models = seeded_llm.id.to_s

        get "/admin/plugins/discourse-ai/ai-spam.json"
        expect(response.status).to eq(200)
        json = response.parsed_body

        expect(json["available_llms"].length).to eq(2)
      end

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

  describe "#fix_errors" do
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
      fab!(:llm_model)

      before do
        sign_in(admin)
        DiscourseAi::AiModeration::SpamScanner.flagging_user.update!(admin: false)
      end

      it "resolves spam scanner not admin error" do
        post "/admin/plugins/discourse-ai/ai-spam/fix-errors",
             params: {
               error: "spam_scanner_not_admin",
             }

        expect(response.status).to eq(200)
        expect(DiscourseAi::AiModeration::SpamScanner.flagging_user.reload.admin).to eq(true)
      end

      it "returns an error when it can't update the user" do
        DiscourseAi::AiModeration::SpamScanner.flagging_user.destroy

        post "/admin/plugins/discourse-ai/ai-spam/fix-errors",
             params: {
               error: "spam_scanner_not_admin",
             }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to be_present
        expect(response.parsed_body["errors"].first).to eq(
          I18n.t("discourse_ai.spam_detection.bot_user_update_failed"),
        )
      end
    end
  end
end
