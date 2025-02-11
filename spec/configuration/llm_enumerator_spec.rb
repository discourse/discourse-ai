# frozen_string_literal: true

RSpec.describe DiscourseAi::Configuration::LlmEnumerator do
  fab!(:fake_model)
  fab!(:llm_model)
  fab!(:seeded_llm_model) { Fabricate(:llm_model, id: -10) }

  describe "#values_for_serialization" do
    it "returns an array for that can be used for serialization" do
      fake_model.destroy!

      expect(described_class.values_for_serialization).to eq(
        [
          {
            id: llm_model.id,
            name: llm_model.display_name,
            vision_enabled: llm_model.vision_enabled,
          },
        ],
      )

      expect(
        described_class.values_for_serialization(
          allowed_seeded_llm_ids: [seeded_llm_model.id.to_s],
        ),
      ).to contain_exactly(
        {
          id: seeded_llm_model.id,
          name: seeded_llm_model.display_name,
          vision_enabled: seeded_llm_model.vision_enabled,
        },
        {
          id: llm_model.id,
          name: llm_model.display_name,
          vision_enabled: llm_model.vision_enabled,
        },
      )
    end
  end

  describe "#global_usage" do
    before do
      SiteSetting.ai_helper_model = "custom:#{fake_model.id}"
      SiteSetting.ai_helper_enabled = true
    end

    it "returns a hash of Llm models in use globally" do
      expect(described_class.global_usage).to eq(fake_model.id => [{ type: :ai_helper }])
    end

    it "doesn't error on spam when spam detection is enabled but moderation setting is missing" do
      SiteSetting.ai_spam_detection_enabled = true
      expect { described_class.global_usage }.not_to raise_error
    end
  end
end
