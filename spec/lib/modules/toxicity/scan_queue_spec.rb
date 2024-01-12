# frozen_string_literal: true

describe DiscourseAi::Toxicity::ScanQueue do
  fab!(:group) { Fabricate(:group) }

  before do
    SiteSetting.ai_toxicity_enabled = true
    SiteSetting.ai_toxicity_groups_bypass = group.id.to_s
  end

  describe "#enqueue_post" do
    fab!(:post) { Fabricate(:post) }

    it "queues a job" do
      expect { described_class.enqueue_post(post) }.to change(
        Jobs::ToxicityClassifyPost.jobs,
        :size,
      ).by(1)
    end

    it "does nothing if ai_toxicity_enabled is disabled" do
      SiteSetting.ai_toxicity_enabled = false

      expect { described_class.enqueue_post(post) }.not_to change(
        Jobs::ToxicityClassifyPost.jobs,
        :size,
      )
    end

    it "does nothing if the user group is allowlisted" do
      group.add(post.user)

      expect { described_class.enqueue_post(post) }.not_to change(
        Jobs::ToxicityClassifyPost.jobs,
        :size,
      )
    end
  end

  describe "#enqueue_chat_message" do
    fab!(:chat_message) { Fabricate(:chat_message) }

    it "queues a job" do
      expect { described_class.enqueue_chat_message(chat_message) }.to change(
        Jobs::ToxicityClassifyChatMessage.jobs,
        :size,
      ).by(1)
    end

    it "does nothing if ai_toxicity_enabled is disabled" do
      SiteSetting.ai_toxicity_enabled = false

      expect { described_class.enqueue_chat_message(chat_message) }.not_to change(
        Jobs::ToxicityClassifyChatMessage.jobs,
        :size,
      )
    end

    it "does nothing if the user group is allowlisted" do
      group.add(chat_message.user)

      expect { described_class.enqueue_chat_message(chat_message) }.not_to change(
        Jobs::ToxicityClassifyChatMessage.jobs,
        :size,
      )
    end
  end
end
