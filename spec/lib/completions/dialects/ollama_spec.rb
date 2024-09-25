# frozen_string_literal: true

require_relative "dialect_context"

RSpec.describe DiscourseAi::Completions::Dialects::Ollama do
  fab!(:model) { Fabricate(:ollama_model) }
  let(:context) { DialectContext.new(described_class, model) }

  describe "#translate" do
    it "translates a prompt written in our generic format to the Ollama format" do
      ollama_version = [
        { role: "system", content: context.system_insts },
        { role: "user", content: context.simple_user_input },
      ]

      translated = context.system_user_scenario

      expect(translated).to eq(ollama_version)
    end

    it "trims content if it's getting too long" do
      model.max_prompt_tokens = 5000
      translated = context.long_user_input_scenario

      expect(translated.last[:role]).to eq("user")
      expect(translated.last[:content].length).to be < context.long_message_text.length
    end
  end

  describe "#max_prompt_tokens" do
    it "returns the max_prompt_tokens from the llm_model" do
      model.max_prompt_tokens = 10000
      expect(context.dialect(nil).max_prompt_tokens).to eq(10000)
    end
  end
end
