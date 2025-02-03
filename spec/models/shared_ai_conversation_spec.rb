# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedAiConversation, type: :model do
  fab!(:claude_2) { Fabricate(:llm_model, name: "claude-2") }

  before do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_bot_enabled = true
    toggle_enabled_bots(bots: [claude_2])
  end

  fab!(:user)

  let(:bad_user_input) { <<~HTML }
    Just trying something `<marquee style="font-size: 200px; color: red;" scrollamount=20>h4cked</marquee>`
  HTML
  let(:raw_with_details) { <<~HTML }
    <details>
    <summary>GitHub pull request diff</summary>
    <p><a href="https://github.com/discourse/discourse-ai/pull/521">discourse/discourse-ai 521</a></p>
    </details>
    <p>This is some other text</p>
  HTML

  let(:bot_user) { claude_2.reload.user }
  let!(:topic) { Fabricate(:private_message_topic, recipient: bot_user) }
  let!(:post1) { Fabricate(:post, topic: topic, post_number: 1, raw: bad_user_input) }
  let!(:post2) { Fabricate(:post, topic: topic, post_number: 2, raw: raw_with_details) }

  describe ".share_conversation" do
    it "creates a new conversation if one does not exist" do
      expect { described_class.share_conversation(user, topic) }.to change {
        described_class.count
      }.by(1)
    end

    it "generates a good onebox" do
      conversation = described_class.share_conversation(user, topic)
      onebox = conversation.onebox
      expect(onebox).not_to include("GitHub pull request diff")
      expect(onebox).not_to include("<details>")

      expect(onebox).to include("AI Conversation with Claude-2")
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

    it "escapes HTML" do
      conversation = described_class.share_conversation(user, topic)
      onebox = conversation.onebox
      expect(onebox).not_to include("</marquee>")
      expect(onebox).to include("AI Conversation with Claude-2")
    end
  end
end
