# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::AiModeration::SpamScanner do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[0]) }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:post) { Fabricate(:post, user: user, topic: topic) }
  fab!(:llm_model) { Fabricate(:llm_model) }
  fab!(:spam_setting) do
    AiModerationSetting.create!(
      setting_type: :spam,
      llm_model: llm_model,
      data: { custom_instructions: "test instructions" }
    )
  end

  before do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_spam_detection_enabled = true
  end

  describe ".enabled?" do
    it "returns true when both settings are enabled" do
      expect(described_class.enabled?).to eq(true)
    end

    it "returns false when discourse_ai is disabled" do
      SiteSetting.discourse_ai_enabled = false
      expect(described_class.enabled?).to eq(false)
    end

    it "returns false when spam detection is disabled" do
      SiteSetting.ai_spam_detection_enabled = false
      expect(described_class.enabled?).to eq(false)
    end
  end

  describe ".should_scan_post?" do
    it "returns true for new users' posts" do
      expect(described_class.should_scan_post?(post)).to eq(true)
    end

    it "returns false for trusted users" do
      post.user.trust_level = TrustLevel[2]
      expect(described_class.should_scan_post?(post)).to eq(false)
    end

    it "returns false for users with many public posts" do
      Fabricate(:post, user: user, topic: topic)
      Fabricate(:post, user: user, topic: topic)
      expect(described_class.should_scan_post?(post)).to eq(true)

      pm = Fabricate(:private_message_topic, user: user)
      Fabricate(:post, user: user, topic: pm)

      expect(described_class.should_scan_post?(post)).to eq(true)

      topic = Fabricate(:topic, user: user)
      Fabricate(:post, user: user, topic: topic)

      expect(described_class.should_scan_post?(post)).to eq(false)
    end

    it "returns false for private messages" do
      pm_topic = Fabricate(:private_message_topic)
      pm_post = Fabricate(:post, topic: pm_topic, user: user)
      expect(described_class.should_scan_post?(pm_post)).to eq(false)
    end

    it "returns false for nil posts" do
      expect(described_class.should_scan_post?(nil)).to eq(false)
    end
  end

  describe ".scanned_max_times?" do
    it "returns true when post has been scanned 3 times" do
      3.times do
        AiSpamLog.create!(
          post: post,
          llm_model: llm_model,
          ai_api_audit_log_id: 1,
          is_spam: false
        )
      end

      expect(described_class.scanned_max_times?(post)).to eq(true)
    end

    it "returns false for posts scanned less than 3 times" do
      expect(described_class.scanned_max_times?(post)).to eq(false)
    end
  end

  describe ".significant_change?" do
    it "returns true for first edits" do
      expect(described_class.significant_change?(nil, "new content")).to eq(true)
    end

    it "returns true for significant changes" do
      old_version = "This is a test post"
      new_version = "This is a completely different post with new content"
      expect(described_class.significant_change?(old_version, new_version)).to eq(true)
    end

    it "returns false for minor changes" do
      old_version = "This is a test post"
      new_version = "This is a test Post" # Only capitalization change
      expect(described_class.significant_change?(old_version, new_version)).to eq(false)
    end
  end

  describe ".new_post" do
    it "enqueues spam scan job for eligible posts" do
      Jobs.expects(:enqueue).with(:ai_spam_scan, post_id: post.id)
      described_class.new_post(post)
    end

    it "doesn't enqueue jobs when disabled" do
      SiteSetting.ai_spam_detection_enabled = false
      Jobs.expects(:enqueue).never
      described_class.new_post(post)
    end
  end

  describe ".edited_post" do
    it "enqueues spam scan job for eligible edited posts" do
      PostRevision.create!(
        post: post,
        modifications: { raw: ["old content", "completely new content"] }
      )

      Jobs.expects(:enqueue).with(:ai_spam_scan, post_id: post.id)
      described_class.edited_post(post)
    end

    it "schedules delayed job when edited too soon after last scan" do
      AiSpamLog.create!(
        post: post,
        llm_model: llm_model,
        ai_api_audit_log_id: 1,
        is_spam: false,
        created_at: 5.minutes.ago
      )

      Jobs.expects(:enqueue_in)
      described_class.edited_post(post)
    end
  end

  describe "integration test" do
    fab!(:llm_model) { Fabricate(:llm_model) }
    let(:api_audit_log) { Fabricate(:api_audit_log) }

    before do
      Jobs.run_immediately!
    end

    it "Correctly handles spam scanning" do
      # we need a proper audit log so
      prompt = nil
      DiscourseAi::Completions::Llm.with_prepared_responses(["spam"]) do |_,_,_prompts|
        described_class.new_post(post)
        prompt = _prompts.first
      end

      content = prompt.messages[1][:content]
      expect(content).to include(post.topic.title)
      expect(content).to include(post.raw)

      log = AiSpamLog.find_by(post: post)

      expect(log.payload).to eq(content)
      expect(log.is_spam).to eq(true)
      expect(post.user.reload.silenced_till).to be_present
      expect(post.topic.reload.visible).to eq(false)
    end
  end
end
