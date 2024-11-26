# frozen_string_literal: true

describe DiscourseAi::GuardianExtensions do
  fab!(:user)
  fab!(:group)
  fab!(:topic)

  before do
    group.add(user)
    assign_fake_provider_to(:ai_summarization_model)
    SiteSetting.ai_summarization_enabled = true
    SiteSetting.ai_summarize_max_topic_gists_per_batch = 1
  end

  let(:anon_guardian) { Guardian.new }
  let(:guardian) { Guardian.new(user) }

  describe "#can_see_summary?" do
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
          summary_type: AiSummary.summary_types[:complete],
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

      it "returns true if user is in a group that is allowed summaries" do
        SiteSetting.ai_pm_summarization_allowed_groups = group.id
        expect(guardian.can_see_summary?(pm)).to eq(true)
      end
    end

    context "when there is no user" do
      it "returns false for anons" do
        expect(anon_guardian.can_see_summary?(topic)).to eq(false)
      end

      it "returns true for anons when there is a cached summary" do
        AiSummary.create!(
          target: topic,
          summarized_text: "test",
          original_content_sha: "123",
          algorithm: "test",
          summary_type: AiSummary.summary_types[:complete],
        )

        expect(guardian.can_see_summary?(topic)).to eq(true)
      end
    end
  end

  describe "#can_see_gists?" do
    before { SiteSetting.ai_hot_topic_gists_allowed_groups = group.id }
    let(:guardian) { Guardian.new(user) }

    context "when there is no user" do
      it "returns false for anons" do
        expect(anon_guardian.can_see_gists?).to eq(false)
      end
    end

    context "when setting is set to everyone" do
      before { SiteSetting.ai_hot_topic_gists_allowed_groups = Group::AUTO_GROUPS[:everyone] }

      it "returns true" do
        expect(guardian.can_see_gists?).to eq(true)
      end
    end

    context "when there is a user but it's not a member of the allowed groups" do
      before { SiteSetting.ai_hot_topic_gists_allowed_groups = "" }

      it "returns false" do
        expect(guardian.can_see_gists?).to eq(false)
      end
    end

    context "when there is a user who is a member of an allowed group" do
      it "returns false" do
        expect(guardian.can_see_gists?).to eq(true)
      end
    end
  end
end
