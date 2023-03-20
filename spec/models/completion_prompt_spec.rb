# frozen_string_literal: true

RSpec.describe CompletionPrompt do
  describe "validations" do
    context "when there are too many messages" do
      it "doesn't accept more than 20 messages" do
        prompt = described_class.new(messages: [{ role: "system", content: "a" }] * 21)

        expect(prompt.valid?).to eq(false)
      end
    end

    context "when the message is over the max length" do
      it "doesn't accept messages when the length is more than 1000 characters" do
        prompt = described_class.new(messages: [{ role: "system", content: "a" * 1001 }])

        expect(prompt.valid?).to eq(false)
      end
    end

    context "when the message has invalid roles" do
      it "doesn't accept messages when the role is invalid" do
        prompt = described_class.new(messages: [{ role: "invalid", content: "a" }])

        expect(prompt.valid?).to eq(false)
      end
    end
  end
end
