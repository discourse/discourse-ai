# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::BotController do
  fab!(:user)
  fab!(:pm_topic) { Fabricate(:private_message_topic) }
  fab!(:pm_post) { Fabricate(:post, topic: pm_topic) }

  before { sign_in(user) }

  describe "#show_debug_info" do
    before do
      SiteSetting.ai_bot_enabled = true
      SiteSetting.discourse_ai_enabled = true
    end

    it "returns a 403 when the user cannot debug the AI bot conversation" do
      get "/discourse-ai/ai-bot/post/#{pm_post.id}/show-debug-info"
      expect(response.status).to eq(403)
    end

    it "returns debug info if the user can debug the AI bot conversation" do
      user = pm_topic.topic_allowed_users.first.user
      sign_in(user)

      AiApiAuditLog.create!(
        post_id: pm_post.id,
        provider_id: 1,
        topic_id: pm_topic.id,
        raw_request_payload: "request",
        raw_response_payload: "response",
        request_tokens: 1,
        response_tokens: 2,
      )

      Group.refresh_automatic_groups!
      SiteSetting.ai_bot_debugging_allowed_groups = user.groups.first.id.to_s

      get "/discourse-ai/ai-bot/post/#{pm_post.id}/show-debug-info"
      expect(response.status).to eq(200)

      expect(response.parsed_body["request_tokens"]).to eq(1)
      expect(response.parsed_body["response_tokens"]).to eq(2)
      expect(response.parsed_body["raw_request_payload"]).to eq("request")
      expect(response.parsed_body["raw_response_payload"]).to eq("response")

      post2 = Fabricate(:post, topic: pm_topic)

      # return previous post if current has no debug info
      get "/discourse-ai/ai-bot/post/#{post2.id}/show-debug-info"
      expect(response.status).to eq(200)
      expect(response.parsed_body["request_tokens"]).to eq(1)
      expect(response.parsed_body["response_tokens"]).to eq(2)
    end
  end

  describe "#stop_streaming_response" do
    let(:redis_stream_key) { "gpt_cancel:#{pm_post.id}" }

    before { Discourse.redis.setex(redis_stream_key, 60, 1) }

    it "returns a 403 when the user cannot see the PM" do
      post "/discourse-ai/ai-bot/post/#{pm_post.id}/stop-streaming"

      expect(response.status).to eq(403)
    end

    it "deletes the key using to track the streaming" do
      sign_in(pm_topic.topic_allowed_users.first.user)

      post "/discourse-ai/ai-bot/post/#{pm_post.id}/stop-streaming"

      expect(response.status).to eq(200)
      expect(Discourse.redis.get(redis_stream_key)).to be_nil
    end
  end

  describe "#show_bot_username" do
    it "returns the username_lower of the selected bot" do
      SiteSetting.ai_bot_enabled = true
      gpt_3_5_bot = "gpt-3.5-turbo"
      expected_username = User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID).username_lower

      get "/discourse-ai/ai-bot/bot-username", params: { username: gpt_3_5_bot }

      expect(response.status).to eq(200)
      expect(response.parsed_body["bot_username"]).to eq(expected_username)
    end
  end
end
