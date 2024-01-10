# frozen_string_literal: true

require_relative "dialect_context"

RSpec.describe DiscourseAi::Completions::Dialects::Mixtral do
  let(:model_name) { "mistralai/Mixtral-8x7B-Instruct-v0.1" }
  let(:context) { DialectContext.new(described_class, model_name) }

  describe "#translate" do
    it "translates a prompt written in our generic format to the Llama2 format" do
      llama2_classic_version = <<~TEXT
      <s> [INST]
      #{context.system_insts}
      #{described_class.tool_preamble}
      <tools>
      #{context.dialect_tools}</tools>
      [/INST] Ok </s>
      [INST]#{context.simple_user_input}[/INST]
      TEXT

      translated = context.system_user_scenario

      expect(translated).to eq(llama2_classic_version)
    end

    it "translates tool messages" do
      expected = +(<<~TEXT).strip
      <s> [INST]
      #{context.system_insts}
      #{described_class.tool_preamble}
      <tools>
      #{context.dialect_tools}</tools>
      [/INST] Ok </s>
      [INST]This is a message by a user[/INST]
      I'm a previous bot reply, that's why there's no user</s>
      [INST]This is a new message by a user[/INST]
      <function_results>
      <result>
      <tool_name>tool_id</tool_name>
      <json>
      "I'm a tool result"
      </json>
      </result>
      </function_results>
      TEXT

      expect(context.multi_turn_scenario).to eq(expected)
    end

    it "trims content if it's getting too long" do
      length = 6_000
      translated = context.long_user_input_scenario(length: length)

      expect(translated.length).to be < context.long_message_text(length: length).length
    end
  end
end
