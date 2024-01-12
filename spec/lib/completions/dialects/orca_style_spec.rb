# frozen_string_literal: true

require_relative "dialect_context"

RSpec.describe DiscourseAi::Completions::Dialects::OrcaStyle do
  let(:model_name) { "StableBeluga2" }
  let(:context) { DialectContext.new(described_class, model_name) }

  describe "#translate" do
    it "translates a prompt written in our generic format to the Llama2 format" do
      llama2_classic_version = <<~TEXT
      ### System:
      #{context.system_insts}
      #{described_class.tool_preamble}
      <tools>
      #{context.dialect_tools}</tools>
      ### User:
      #{context.simple_user_input}
      ### Assistant:
      TEXT

      translated = context.system_user_scenario

      expect(translated).to eq(llama2_classic_version)
    end

    it "translates tool messages" do
      expected = +(<<~TEXT)
      ### System:
      #{context.system_insts}
      #{described_class.tool_preamble}
      <tools>
      #{context.dialect_tools}</tools>
      ### User:
      This is a message by a user
      ### Assistant:
      I'm a previous bot reply, that's why there's no user
      ### User:
      This is a new message by a user
      ### Assistant:
      <function_results>
      <result>
      <tool_name>tool_id</tool_name>
      <json>
      "I'm a tool result"
      </json>
      </result>
      </function_results>
      ### Assistant:
      TEXT

      expect(context.multi_turn_scenario).to eq(expected)
    end

    it "trims content if it's getting too long" do
      translated = context.long_user_input_scenario

      expect(translated.length).to be < context.long_message_text.length
    end
  end
end
