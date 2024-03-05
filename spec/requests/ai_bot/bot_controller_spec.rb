# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::BotController do
  fab!(:user)
  before { sign_in(user) }

  describe "#stop_streaming_response" do
    fab!(:pm_topic) { Fabricate(:private_message_topic) }
    fab!(:pm_post) { Fabricate(:post, topic: pm_topic) }

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
