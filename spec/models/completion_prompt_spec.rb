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
  end

  describe "messages_with_input" do
    let(:user_input) { "A user wrote this." }

    context "when the record has the custom_prompt type" do
      let(:custom_prompt) { described_class.find(described_class::CUSTOM_PROMPT) }

      it "wraps the user input with <input> XML tags and adds a custom instruction if given" do
        expected = <<~TEXT
        <input>
        Translate to Turkish:
        #{user_input}
        </input>
        TEXT

        custom_prompt.custom_instruction = "Translate to Turkish"

        prompt = custom_prompt.messages_with_input(user_input)

        expect(prompt[:input]).to eq(expected)
      end
    end

    context "when the records don't have the custom_prompt type" do
      let(:title_prompt) { described_class.find(described_class::GENERATE_TITLES) }

      it "wraps user input with <input> XML tags" do
        expected = <<~TEXT
        <input>
        #{user_input}
        </input>
        TEXT
        title_prompt.custom_instruction = "Translate to Turkish"

        prompt = title_prompt.messages_with_input(user_input)

        expect(prompt[:input]).to eq(expected)
      end
    end
  end
end
