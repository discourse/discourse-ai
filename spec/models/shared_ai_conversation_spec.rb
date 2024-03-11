# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedAiConversation, type: :model do
  before do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_bot_enabled_chat_bots = "claude-2"
    SiteSetting.ai_bot_enabled = true
  end

  fab!(:user)

  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::CLAUDE_V2_ID) }
  let!(:topic) { Fabricate(:private_message_topic, recipient: bot_user) }
  let!(:post1) { Fabricate(:post, topic: topic, post_number: 1) }
  let!(:post2) { Fabricate(:post, topic: topic, post_number: 2) }

  describe ".share_conversation" do
    it "creates a new conversation if one does not exist" do
      expect { described_class.share_conversation(user, topic) }.to change {
        described_class.count
      }.by(1)
    end

    it "updates an existing conversation if one exists" do
      conversation = described_class.share_conversation(user, topic)
      expect(conversation.share_key).to be_present

      topic.update!(title: "New title")

      expect { described_class.share_conversation(user, topic) }.to_not change {
        described_class.count
      }
      expect(conversation.reload.title).to eq("New title")
      expect(conversation.share_key).to be_present
    end

    it "includes the correct conversation data" do
      conversation = described_class.share_conversation(user, topic)
      expect(conversation.llm_name).to eq("Claude-2")
      expect(conversation.title).to eq(topic.title)
      expect(conversation.context.size).to eq(2)
      expect(conversation.context[0]["id"]).to eq(post1.id)
      expect(conversation.context[1]["id"]).to eq(post2.id)

      populated_context = conversation.populated_context

      expect(populated_context[0].id).to eq(post1.id)
      expect(populated_context[0].user.id).to eq(post1.user.id)
      expect(populated_context[1].id).to eq(post2.id)
      expect(populated_context[1].user.id).to eq(post2.user.id)
    end
  end
end
