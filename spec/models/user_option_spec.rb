# frozen_string_literal: true

RSpec.describe UserOption do
  before do
    assign_fake_provider_to(:ai_helper_model)
    assign_fake_provider_to(:ai_helper_image_caption_model)
    SiteSetting.ai_helper_enabled = true
    SiteSetting.ai_helper_enabled_features = "image_caption"
    SiteSetting.ai_auto_image_caption_allowed_groups = "10" # tl0
  end

  describe "#auto_image_caption" do
    it "is present" do
      expect(described_class.new.auto_image_caption).to eq(false)
    end
  end
end
