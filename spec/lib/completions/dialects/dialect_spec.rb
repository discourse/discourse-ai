# frozen_string_literal: true

class TestDialect < DiscourseAi::Completions::Dialects::Dialect
  attr_accessor :max_prompt_tokens

  def trim(messages)
    trim_messages(messages)
  end

  def tokenizer
    DiscourseAi::Tokenizer::OpenAiTokenizer
  end
end

RSpec.describe DiscourseAi::Completions::Dialects::Dialect do
  describe "#trim_messages" do
    let(:five_token_msg) { "This represents five tokens." }

    it "should trim tool messages if tool_calls are trimmed" do
      prompt = DiscourseAi::Completions::Prompt.new(five_token_msg)
      prompt.push(type: :user, content: five_token_msg)
      prompt.push(type: :tool_call, content: five_token_msg, id: 1)
      prompt.push(type: :tool, content: five_token_msg, id: 1)
      prompt.push(type: :user, content: five_token_msg)

      dialect = TestDialect.new(prompt, "test")
      dialect.max_prompt_tokens = 15 # fits the user messages and the tool_call message

      trimmed = dialect.trim(prompt.messages)

      expect(trimmed).to eq(
        [{ type: :system, content: five_token_msg }, { type: :user, content: five_token_msg }],
      )
    end

    it "limits the system message to 60% of available tokens" do
      prompt = DiscourseAi::Completions::Prompt.new("I'm a system message consisting of 10 tokens")
      prompt.push(type: :user, content: five_token_msg)

      dialect = TestDialect.new(prompt, "test")
      dialect.max_prompt_tokens = 15

      trimmed = dialect.trim(prompt.messages)

      expect(trimmed).to eq(
        [
          { type: :system, content: "I'm a system message consisting of 10" },
          { type: :user, content: five_token_msg },
        ],
      )
    end
  end
end
