# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Dialects::Claude do
  describe "#translate" do
    it "can insert OKs to make stuff interleve properly" do
      messages = [
        { type: :user, id: "user1", content: "1" },
        { type: :model, content: "2" },
        { type: :user, id: "user1", content: "4" },
        { type: :user, id: "user1", content: "5" },
        { type: :model, content: "6" },
      ]

      prompt = DiscourseAi::Completions::Prompt.new("You are a helpful bot", messages: messages)

      dialectKlass = DiscourseAi::Completions::Dialects::Dialect.dialect_for("claude-3-opus")
      dialect = dialectKlass.new(prompt, "claude-3-opus")
      translated = dialect.translate

      expected_messages = [
        { role: "user", content: "user1: 1" },
        { role: "assistant", content: "2" },
        { role: "user", content: "user1: 4" },
        { role: "assistant", content: "OK" },
        { role: "user", content: "user1: 5" },
        { role: "assistant", content: "6" },
      ]

      expect(translated.messages).to eq(expected_messages)
    end

    it "can properly translate a prompt" do
      dialect = DiscourseAi::Completions::Dialects::Dialect.dialect_for("claude-3-opus")

      tools = [
        {
          name: "echo",
          description: "echo a string",
          parameters: [
            { name: "text", type: "string", description: "string to echo", required: true },
          ],
        },
      ]

      tool_call_prompt = { name: "echo", arguments: { text: "something" } }

      messages = [
        { type: :user, id: "user1", content: "echo something" },
        { type: :tool_call, name: "echo", id: "tool_id", content: tool_call_prompt.to_json },
        { type: :tool, id: "tool_id", content: "something".to_json },
        { type: :model, content: "I did it" },
        { type: :user, id: "user1", content: "echo something else" },
      ]

      prompt =
        DiscourseAi::Completions::Prompt.new(
          "You are a helpful bot",
          messages: messages,
          tools: tools,
        )

      dialect = dialect.new(prompt, "claude-3-opus")
      translated = dialect.translate

      expect(translated.system_prompt).to start_with("You are a helpful bot")

      expected = [
        { role: "user", content: "user1: echo something" },
        {
          role: "assistant",
          content: [
            { type: "tool_use", id: "tool_id", name: "echo", input: { text: "something" } },
          ],
        },
        {
          role: "user",
          content: [{ type: "tool_result", tool_use_id: "tool_id", content: "\"something\"" }],
        },
        { role: "assistant", content: "I did it" },
        { role: "user", content: "user1: echo something else" },
      ]
      expect(translated.messages).to eq(expected)
    end
  end
end
