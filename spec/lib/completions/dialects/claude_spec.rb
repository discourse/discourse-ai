# frozen_string_literal: true

require_relative "dialect_context"

RSpec.describe DiscourseAi::Completions::Dialects::Claude do
  let(:model_name) { "claude-2" }
  let(:context) { DialectContext.new(described_class, model_name) }

  describe "#translate" do
    it "translates a prompt written in our generic format to Claude's format" do
      anthropic_version = (<<~TEXT).strip
      #{context.system_insts}
      #{described_class.tool_preamble}
      <tools>
      #{context.dialect_tools}</tools>

      Human: #{context.simple_user_input}
      
      Assistant:
      TEXT

      translated = context.system_user_scenario

      expect(translated).to eq(anthropic_version)
    end

    it "translates tool messages" do
      expected = +(<<~TEXT).strip
      #{context.system_insts}
      #{described_class.tool_preamble}
      <tools>
      #{context.dialect_tools}</tools>

      Human: This is a message by a user

      Assistant: I'm a previous bot reply, that's why there's no user

      Human: This is a new message by a user

      Assistant:
      <function_results>
      <result>
      <tool_name>tool_id</tool_name>
      <json>
      "I'm a tool result"
      </json>
      </result>
      </function_results>
      
      Assistant:
      TEXT

      expect(context.multi_turn_scenario).to eq(expected)
    end

    it "trims content if it's getting too long" do
      length = 19_000

      translated = context.long_user_input_scenario(length: length)

      expect(translated.length).to be < context.long_message_text(length: length).length
    end
  end
end
