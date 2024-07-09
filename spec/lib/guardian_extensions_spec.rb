# frozen_string_literal: true

describe DiscourseAi::GuardianExtensions do
  fab!(:user)
  fab!(:group)
  fab!(:topic)

  before do
    group.add(user)
    assign_fake_provider_to(:ai_summarization_model)
    SiteSetting.ai_summarization_enabled = true
  end

  describe "#can_see_summary?" do
    let(:guardian) { Guardian.new(user) }

    context "when the user cannot generate a summary" do
      before { SiteSetting.ai_custom_summarization_allowed_groups = "" }

      it "returns false" do
        SiteSetting.ai_custom_summarization_allowed_groups = ""

        expect(guardian.can_see_summary?(topic)).to eq(false)
      end

      it "returns true if there is a cached summary" do
        AiSummary.create!(
          target: topic,
          summarized_text: "test",
          original_content_sha: "123",
          algorithm: "test",
        )

        expect(guardian.can_see_summary?(topic)).to eq(true)
      end
    end

    context "when the user can generate a summary" do
      before { SiteSetting.ai_custom_summarization_allowed_groups = group.id }

      it "returns true if the user group is present in the ai_custom_summarization_allowed_groups_map setting" do
        expect(guardian.can_see_summary?(topic)).to eq(true)
      end
    end

    context "when the topic is a PM" do
      before { SiteSetting.ai_custom_summarization_allowed_groups = group.id }
      let(:pm) { Fabricate(:private_message_topic) }

      it "returns false" do
        expect(guardian.can_see_summary?(pm)).to eq(false)
      end
    end

    context "when there is no user" do
      let(:guardian) { Guardian.new }

      it "returns false for anons" do
        expect(guardian.can_see_summary?(topic)).to eq(false)
      end

      it "returns true for anons when there is a cached summary" do
        AiSummary.create!(
          target: topic,
          summarized_text: "test",
          original_content_sha: "123",
          algorithm: "test",
        )

        expect(guardian.can_see_summary?(topic)).to eq(true)
      end
    end
  end
end
