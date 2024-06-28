# frozen_string_literal: true

require_relative "../../../support/dummy_custom_summarization"

describe DiscourseAi::Summarization::Models::Base do
  fab!(:user)
  fab!(:group)
  fab!(:topic)

  let(:plugin) { Plugin::Instance.new }

  before do
    group.add(user)

    strategy = DummyCustomSummarization.new({ summary: "dummy" })
    SiteSetting.ai_summarization_strategy = strategy.model
  end

  after { DiscoursePluginRegistry.reset_register!(:summarization_strategies) }

  describe "#can_see_summary?" do
    context "when the user cannot generate a summary" do
      before { SiteSetting.custom_summarization_allowed_groups = "" }

      it "returns false" do
        SiteSetting.custom_summarization_allowed_groups = ""

        expect(described_class.can_see_summary?(topic, user)).to eq(false)
      end

      it "returns true if there is a cached summary" do
        AiSummary.create!(
          target: topic,
          summarized_text: "test",
          original_content_sha: "123",
          algorithm: "test",
        )

        expect(described_class.can_see_summary?(topic, user)).to eq(true)
      end
    end

    context "when the user can generate a summary" do
      before { SiteSetting.custom_summarization_allowed_groups = group.id }

      it "returns true if the user group is present in the custom_summarization_allowed_groups_map setting" do
        expect(described_class.can_see_summary?(topic, user)).to eq(true)
      end
    end

    context "when there is no user" do
      it "returns false for anons" do
        expect(described_class.can_see_summary?(topic, nil)).to eq(false)
      end

      it "returns true for anons when there is a cached summary" do
        AiSummary.create!(
          target: topic,
          summarized_text: "test",
          original_content_sha: "123",
          algorithm: "test",
        )

        expect(described_class.can_see_summary?(topic, nil)).to eq(true)
      end
    end

    context "when the topic is a PM" do
      before { SiteSetting.custom_summarization_allowed_groups = group.id }
      let(:pm) { Fabricate(:private_message_topic) }

      it "returns false" do
        expect(described_class.can_see_summary?(pm, user)).to eq(false)
      end
    end
  end
end
