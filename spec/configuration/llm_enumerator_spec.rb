# frozen_string_literal: true

RSpec.describe DiscourseAi::Configuration::LlmEnumerator do
  fab!(:fake_model)

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
