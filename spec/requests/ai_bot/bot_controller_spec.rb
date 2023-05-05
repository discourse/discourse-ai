# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::BotController do
  describe "#stop_streaming_response" do
    fab!(:pm_topic) { Fabricate(:private_message_topic) }
    fab!(:pm_post) { Fabricate(:post, topic: pm_topic) }

    let(:redis_stream_key) { "gpt_cancel:#{pm_post.id}" }

    before { Discourse.redis.setex(redis_stream_key, 60, 1) }

    it "returns a 403 when the user cannot see the PM" do
      sign_in(Fabricate(:user))

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
end
