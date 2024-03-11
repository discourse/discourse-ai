# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::AiBot::SharedAiConversationsController do
  before do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_bot_enabled_chat_bots = "claude-2"
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_allowed_groups = "10"
    SiteSetting.ai_bot_allow_public_sharing = true
  end

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic)
  fab!(:pm) { Fabricate(:private_message_topic) }
  fab!(:user_pm) { Fabricate(:private_message_topic, recipient: user) }

  fab!(:bot_user) do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_bot_enabled_chat_bots = "claude-2"
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_allowed_groups = "10"
    SiteSetting.ai_bot_allow_public_sharing = true
    User.find(DiscourseAi::AiBot::EntryPoint::CLAUDE_V2_ID)
  end

  fab!(:user_pm_share) do
    pm_topic = Fabricate(:private_message_topic, user: user, recipient: bot_user)
    # a different unknown user
    Fabricate(:post, topic: pm_topic, user: user)
    Fabricate(:post, topic: pm_topic, user: bot_user)
    Fabricate(:post, topic: pm_topic, user: user)
    pm_topic
  end

  let(:path) { "/discourse-ai/ai-bot/shared-ai-conversations" }
  let(:shared_conversation) { SharedAiConversation.share_conversation(user, user_pm_share) }

  def share_error(key)
    I18n.t("discourse_ai.share_ai.errors.#{key}")
  end

  describe "POST create" do
    context "when logged in" do
      before { sign_in(user) }

      it "denies creating a new shared conversation on public topics" do
        post "#{path}.json", params: { topic_id: topic.id }
        expect(response).not_to have_http_status(:success)

        expect(response.parsed_body["errors"]).to eq([share_error(:not_allowed)])
        expect(response.parsed_body["errors"].to_s).not_to include("Translation missing")
      end

      it "denies creating a new shared conversation for a random PM" do
        post "#{path}.json", params: { topic_id: pm.id }
        expect(response).not_to have_http_status(:success)

        expect(response.parsed_body["errors"]).to eq([share_error(:not_allowed)])
        expect(response.parsed_body["errors"].to_s).not_to include("Translation missing")
      end

      it "denies creating a shared conversation for my PMs not with bots" do
        post "#{path}.json", params: { topic_id: user_pm.id }
        expect(response).not_to have_http_status(:success)
        expect(response.parsed_body["errors"]).to eq([share_error(:other_people_in_pm)])
        expect(response.parsed_body["errors"].to_s).not_to include("Translation missing")
      end

      it "denies creating a shared conversation for my PMs with bots that also have other users" do
        pm_topic = Fabricate(:private_message_topic, user: user, recipient: bot_user)
        # a different unknown user
        Fabricate(:post, topic: pm_topic)
        post "#{path}.json", params: { topic_id: pm_topic.id }
        expect(response).not_to have_http_status(:success)

        expect(response.parsed_body["errors"]).to eq([share_error(:other_content_in_pm)])
        expect(response.parsed_body["errors"].to_s).not_to include("Translation missing")
      end

      it "allows creating a shared conversation for my PMs with bots only" do
        post "#{path}.json", params: { topic_id: user_pm_share.id }
        expect(response).to have_http_status(:success)
      end
    end

    context "when not logged in" do
      it "requires login" do
        post "#{path}.json", params: { topic_id: topic.id }
        expect(response).not_to have_http_status(:success)
      end
    end
  end

  describe "DELETE destroy" do
    context "when logged in" do
      before { sign_in(user) }

      it "deletes the shared conversation" do
        delete "#{path}/#{shared_conversation.share_key}.json"
        expect(response).to have_http_status(:success)
        expect(SharedAiConversation.exists?(shared_conversation.id)).to be_falsey
      end

      it "returns an error if the shared conversation is not found" do
        delete "#{path}/123.json"
        expect(response).not_to have_http_status(:success)
      end
    end

    context "when not logged in" do
      it "requires login" do
        delete "#{path}/#{shared_conversation.share_key}.json"
        expect(response).not_to have_http_status(:success)
      end
    end
  end

  describe "GET preview" do
    it "denies preview from logged out users" do
      get "#{path}/preview/#{user_pm_share.id}.json"
      expect(response).not_to have_http_status(:success)
    end

    context "when logged in" do
      before { sign_in(user) }

      it "renders the shared conversation" do
        get "#{path}/preview/#{user_pm_share.id}.json"
        expect(response).to have_http_status(:success)
        expect(response.parsed_body["llm_name"]).to eq("Claude-2")
        expect(response.parsed_body["error"]).to eq(nil)
        expect(response.parsed_body["share_key"]).to eq(nil)
        expect(response.parsed_body["context"].length).to eq(3)

        shared_conversation
        get "#{path}/preview/#{user_pm_share.id}.json"

        expect(response).to have_http_status(:success)
        expect(response.parsed_body["share_key"]).to eq(shared_conversation.share_key)

        SiteSetting.ai_bot_allow_public_sharing = false
        get "#{path}/preview/#{user_pm_share.id}.json"
        expect(response).not_to have_http_status(:success)
      end
    end
  end

  describe "GET show" do
    it "renders the shared conversation" do
      get "#{path}/#{shared_conversation.share_key}"
      expect(response).to have_http_status(:success)
      expect(response.headers["Cache-Control"]).to eq("max-age=60, public")
      expect(response.headers["X-Robots-Tag"]).to eq("noindex")
    end

    it "is also able to render in json format" do
      get "#{path}/#{shared_conversation.share_key}.json"
      expect(response.parsed_body["llm_name"]).to eq("Claude-2")
      expect(response.headers["X-Robots-Tag"]).to eq("noindex")
    end

    it "returns an error if the shared conversation is not found" do
      get "#{path}/123"
      expect(response).to have_http_status(:not_found)
    end
  end
end
