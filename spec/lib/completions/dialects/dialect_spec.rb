# frozen_string_literal: true

class TestDialect < DiscourseAi::Completions::Dialects::Dialect
  attr_accessor :max_prompt_tokens

  def trim(messages)
    trim_messages(messages)
  end

  def tokenizer
    Class.new do
      def self.size(str)
        str.length
      end
    end
  end
end

RSpec.describe DiscourseAi::Completions::Dialects::Dialect do
  describe "#trim_messages" do
    it "should trim tool messages if tool_calls are trimmed" do
      prompt = DiscourseAi::Completions::Prompt.new("12345")
      prompt.push(type: :user, content: "12345")
      prompt.push(type: :tool_call, content: "12345", id: 1)
      prompt.push(type: :tool, content: "12345", id: 1)
      prompt.push(type: :user, content: "12345")

      dialect = TestDialect.new(prompt, "test")
      dialect.max_prompt_tokens = 15 # fits the user messages and the tool_call message

      trimmed = dialect.trim(prompt.messages)

      expect(trimmed).to eq(
        [{ type: :system, content: "12345" }, { type: :user, content: "12345" }],
      )
    end
  end
end
