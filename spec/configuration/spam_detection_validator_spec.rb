# frozen_string_literal: true

RSpec.describe DiscourseAi::Configuration::SpamDetectionValidator do
  describe "#valid_value?" do
    context "when AiModeratinSetting.spam does not exist" do
      it "returns false and displays an error message" do
        validator = described_class.new

        value = validator.valid_value?(true)

        expect(value).to eq(false)
        expect(validator.error_message).to include(
          I18n.t("discourse_ai.spam_detection.configuration_missing"),
        )
      end
    end
  end
end
