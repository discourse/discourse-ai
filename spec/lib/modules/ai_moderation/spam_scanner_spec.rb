# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::AiModeration::SpamScanner do
  fab!(:moderator)
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[0]) }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, user: user, topic: topic) }
  fab!(:llm_model)
  fab!(:spam_setting) do
    AiModerationSetting.create!(
      setting_type: :spam,
      llm_model: llm_model,
      data: {
        custom_instructions: "test instructions",
      },
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

  describe ".perform_scan" do
    it "does nothing if post should not be scanned" do
      post.user.trust_level = TrustLevel[2]

      expect { described_class.perform_scan(post) }.not_to change { AiSpamLog.count }
    end

    it "scans when post should be scanned" do
      expect do
        DiscourseAi::Completions::Llm.with_prepared_responses(["spam"]) do
          described_class.perform_scan!(post)
        end
      end.to change { AiSpamLog.count }.by(1)
    end
  end

  describe ".perform_scan!" do
    it "creates spam log entry when scanning post" do
      expect do
        DiscourseAi::Completions::Llm.with_prepared_responses(["spam"]) do
          described_class.perform_scan!(post)
        end
      end.to change { AiSpamLog.count }.by(1)
    end

    it "does nothing when disabled" do
      SiteSetting.ai_spam_detection_enabled = false
      expect { described_class.perform_scan!(post) }.not_to change { AiSpamLog.count }
    end
  end

  describe ".scanned_max_times?" do
    it "returns true when post has been scanned 3 times" do
      3.times do
        AiSpamLog.create!(post: post, llm_model: llm_model, ai_api_audit_log_id: 1, is_spam: false)
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
      expect {
        described_class.new_post(post)
        described_class.after_cooked_post(post)
      }.to change(Jobs::AiSpamScan.jobs, :size).by(1)
    end

    it "doesn't enqueue jobs when disabled" do
      SiteSetting.ai_spam_detection_enabled = false
      expect { described_class.new_post(post) }.not_to change(Jobs::AiSpamScan.jobs, :size)
    end
  end

  describe ".edited_post" do
    it "enqueues spam scan job for eligible edited posts" do
      PostRevision.create!(
        post: post,
        modifications: {
          raw: ["old content", "completely new content"],
        },
      )

      expect {
        described_class.edited_post(post)
        described_class.after_cooked_post(post)
      }.to change(Jobs::AiSpamScan.jobs, :size).by(1)
    end

    it "schedules delayed job when edited too soon after last scan" do
      AiSpamLog.create!(
        post: post,
        llm_model: llm_model,
        ai_api_audit_log_id: 1,
        is_spam: false,
        created_at: 5.minutes.ago,
      )

      expect {
        described_class.edited_post(post)
        described_class.after_cooked_post(post)
      }.to change(Jobs::AiSpamScan.jobs, :size).by(1)
    end
  end

  describe ".hide_post" do
    fab!(:spam_post) { Fabricate(:post, user: user) }
    fab!(:second_spam_post) { Fabricate(:post, topic: spam_post.topic, user: user) }

    it "hides spam post and topic for first post" do
      described_class.hide_post(spam_post)

      expect(spam_post.reload.hidden).to eq(true)
      expect(second_spam_post.reload.hidden).to eq(false)
      expect(spam_post.reload.hidden_reason_id).to eq(
        Post.hidden_reasons[:new_user_spam_threshold_reached],
      )
    end

    it "doesn't hide the topic for non-first posts" do
      described_class.hide_post(second_spam_post)

      expect(spam_post.reload.hidden).to eq(false)
      expect(second_spam_post.reload.hidden).to eq(true)
      expect(spam_post.topic.reload.visible).to eq(true)
    end
  end

  describe "integration test" do
    fab!(:llm_model)
    let(:api_audit_log) { Fabricate(:api_audit_log) }
    fab!(:post_with_uploaded_image)

    before { Jobs.run_immediately! }

    it "Can correctly run tests" do
      prompts = nil
      result =
        DiscourseAi::Completions::Llm.with_prepared_responses(
          ["spam", "the reason is just because"],
        ) do |_, _, _prompts|
          prompts = _prompts
          described_class.test_post(post, custom_instructions: "123")
        end

      expect(prompts.length).to eq(2)
      expect(result[:is_spam]).to eq(true)
      expect(result[:log]).to include("123")
      expect(result[:log]).to include("just because")

      result =
        DiscourseAi::Completions::Llm.with_prepared_responses(
          ["not_spam", "the reason is just because"],
        ) do |_, _, _prompts|
          prompts = _prompts
          described_class.test_post(post, custom_instructions: "123")
        end

      expect(result[:is_spam]).to eq(false)
    end

    it "Correctly handles spam scanning" do
      expect(described_class.flagging_user.id).not_to eq(Discourse.system_user.id)

      # flag post for scanning
      post = post_with_uploaded_image

      described_class.new_post(post)

      prompt = nil
      DiscourseAi::Completions::Llm.with_prepared_responses(["spam"]) do |_, _, _prompts|
        # force a rebake so we actually scan
        post.rebake!
        prompt = _prompts.first
      end

      content = prompt.messages[1][:content]
      expect(content).to include(post.topic.title)
      expect(content).to include(post.raw)

      upload_ids = prompt.messages[1][:upload_ids]
      expect(upload_ids).to be_present
      expect(upload_ids).to eq(post.upload_ids)

      log = AiSpamLog.find_by(post: post)

      expect(log.payload).to eq(content)
      expect(log.is_spam).to eq(true)
      expect(post.user.reload.silenced_till).to be_present
      expect(post.topic.reload.visible).to eq(false)

      history = UserHistory.where(action: UserHistory.actions[:silence_user]).order(:id).last

      url = "#{Discourse.base_url}/admin/plugins/discourse-ai/ai-spam"

      expect(history.target_user_id).to eq(post.user_id)
      expect(history.details).to include(
        I18n.t("discourse_ai.spam_detection.silence_reason", url: url),
      )

      expect(log.reviewable).to be_present
      expect(log.reviewable.created_by_id).to eq(described_class.flagging_user.id)

      log.reviewable.perform(moderator, :disagree_and_restore)

      expect(post.reload.hidden?).to eq(false)
      expect(post.topic.reload.visible).to eq(true)
      expect(post.user.reload.silenced?).to eq(false)
    end
  end
end
