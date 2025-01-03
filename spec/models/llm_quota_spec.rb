# frozen_string_literal: true
#
RSpec.describe LlmQuota do
  fab!(:group)
  fab!(:user)
  fab!(:llm_model)

  before { group.add(user) }

  describe ".within_quota?" do
    it "returns true when user is nil" do
      expect(described_class.within_quota?(llm_model, nil)).to be true
    end

    it "returns true when no quotas exist for the user's groups" do
      expect(described_class.within_quota?(llm_model, user)).to be true
    end

    it "returns true when usage is within limits" do
      quota = Fabricate(:llm_quota, group: group, llm_model: llm_model)
      _usage =
        Fabricate(
          :llm_quota_usage,
          user: user,
          llm_quota: quota,
          input_tokens_used: quota.max_tokens - 100,
        )

      expect(described_class.within_quota?(llm_model, user)).to be true
    end

    it "returns false when usage exceeds token limit" do
      quota = Fabricate(:llm_quota, group: group, llm_model: llm_model, max_tokens: 1000)
      _usage = Fabricate(:llm_quota_usage, user: user, llm_quota: quota, input_tokens_used: 1100)

      expect(described_class.within_quota?(llm_model, user)).to be false
    end

    it "returns false when usage exceeds usage limit" do
      quota = Fabricate(:llm_quota, group: group, llm_model: llm_model, max_usages: 10)
      _usage = Fabricate(:llm_quota_usage, user: user, llm_quota: quota, usages: 11)

      expect(described_class.within_quota?(llm_model, user)).to be false
    end

    it "checks all quotas from user's groups" do
      group2 = Fabricate(:group)
      group2.add(user)

      quota1 = Fabricate(:llm_quota, group: group, llm_model: llm_model, max_tokens: 1000)
      quota2 = Fabricate(:llm_quota, group: group2, llm_model: llm_model, max_tokens: 500)

      Fabricate(:llm_quota_usage, user: user, llm_quota: quota1, input_tokens_used: 900)
      Fabricate(:llm_quota_usage, user: user, llm_quota: quota2, input_tokens_used: 600)

      expect(described_class.within_quota?(llm_model, user)).to be false
    end
  end

  describe ".log_usage" do
    it "does nothing when user is nil" do
      expect { described_class.log_usage(llm_model, nil, 100, 50) }.not_to change(
        LlmQuotaUsage,
        :count,
      )
    end

    it "creates usage records when none exist" do
      _quota = Fabricate(:llm_quota, group: group, llm_model: llm_model)

      expect { described_class.log_usage(llm_model, user, 100, 50) }.to change(
        LlmQuotaUsage,
        :count,
      ).by(1)

      usage = LlmQuotaUsage.last
      expect(usage.input_tokens_used).to eq(100)
      expect(usage.output_tokens_used).to eq(50)
      expect(usage.usages).to eq(1)
    end

    it "updates existing usage records" do
      quota = Fabricate(:llm_quota, group: group, llm_model: llm_model)
      usage =
        Fabricate(
          :llm_quota_usage,
          user: user,
          llm_quota: quota,
          input_tokens_used: 100,
          output_tokens_used: 50,
          usages: 1,
        )

      described_class.log_usage(llm_model, user, 50, 25)

      usage.reload
      expect(usage.input_tokens_used).to eq(150)
      expect(usage.output_tokens_used).to eq(75)
      expect(usage.usages).to eq(2)
    end

    it "logs usage for all quotas from user's groups" do
      group2 = Fabricate(:group)
      group2.add(user)

      _quota1 = Fabricate(:llm_quota, group: group, llm_model: llm_model)
      _quota2 = Fabricate(:llm_quota, group: group2, llm_model: llm_model)

      expect { described_class.log_usage(llm_model, user, 100, 50) }.to change(
        LlmQuotaUsage,
        :count,
      ).by(2)

      expect(LlmQuotaUsage.where(user: user).count).to eq(2)
    end
  end
end
