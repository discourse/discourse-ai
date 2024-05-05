# frozen_string_literal: true

describe DiscourseAi::Completions::PromptMessagesBuilder do
  let(:builder) { DiscourseAi::Completions::PromptMessagesBuilder.new }

  it "should allow merging user messages" do
    builder.push(type: :user, content: "Hello", name: "Alice")
    builder.push(type: :user, content: "World", name: "Bob")

    expect(builder.to_a).to eq([{ type: :user, content: "Alice: Hello\nBob: World" }])
  end

  it "should allow adding uploads" do
    builder.push(type: :user, content: "Hello", name: "Alice", upload_ids: [1, 2])

    expect(builder.to_a).to eq(
      [{ type: :user, name: "Alice", content: "Hello", upload_ids: [1, 2] }],
    )
  end

  it "should support function calls" do
    builder.push(type: :user, content: "Echo 123 please", name: "Alice")
    builder.push(type: :tool_call, content: "echo(123)", name: "echo", id: 1)
    builder.push(type: :tool, content: "123", name: "echo", id: 1)
    builder.push(type: :user, content: "Hello", name: "Alice")
    expected = [
      { type: :user, content: "Echo 123 please", name: "Alice" },
      { type: :tool_call, content: "echo(123)", name: "echo", id: "1" },
      { type: :tool, content: "123", name: "echo", id: "1" },
      { type: :user, content: "Hello", name: "Alice" },
    ]
    expect(builder.to_a).to eq(expected)
  end

  it "should drop a tool call if it is not followed by tool" do
    builder.push(type: :user, content: "Echo 123 please", name: "Alice")
    builder.push(type: :tool_call, content: "echo(123)", name: "echo", id: 1)
    builder.push(type: :user, content: "OK", name: "James")

    expected = [{ type: :user, content: "Alice: Echo 123 please\nJames: OK" }]
    expect(builder.to_a).to eq(expected)
  end
end
