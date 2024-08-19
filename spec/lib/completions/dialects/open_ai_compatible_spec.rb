# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Dialects::OpenAiCompatible do
  context "when system prompts are disabled" do
    it "merges the system prompt into the first message" do
      system_msg = "This is a system message"
      user_msg = "user message"
      prompt =
        DiscourseAi::Completions::Prompt.new(
          system_msg,
          messages: [{ type: :user, content: user_msg }],
        )

      model = Fabricate(:vllm_model, provider_params: { disable_system_prompt: true })

      translated_messages = described_class.new(prompt, model).translate

      expect(translated_messages.length).to eq(1)
      expect(translated_messages).to contain_exactly(
        { role: "user", content: [system_msg, user_msg].join("\n") },
      )
    end
  end

  context "when system prompts are enabled" do
    it "includes system and user messages separately" do
      system_msg = "This is a system message"
      user_msg = "user message"
      prompt =
        DiscourseAi::Completions::Prompt.new(
          system_msg,
          messages: [{ type: :user, content: user_msg }],
        )

      model = Fabricate(:vllm_model, provider_params: { disable_system_prompt: false })

      translated_messages = described_class.new(prompt, model).translate

      expect(translated_messages.length).to eq(2)
      expect(translated_messages).to contain_exactly(
        { role: "system", content: system_msg },
        { role: "user", content: user_msg },
      )
    end
  end
end
