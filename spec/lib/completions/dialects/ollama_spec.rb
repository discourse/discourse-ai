# frozen_string_literal: true

require_relative "dialect_context"

RSpec.describe DiscourseAi::Completions::Dialects::Ollama do
  fab!(:model) { Fabricate(:ollama_model) }
  let(:context) { DialectContext.new(described_class, model) }

  describe "#translate" do
    context "when native tool support is enabled" do
      it "translates a prompt written in our generic format to the Ollama format" do
        ollama_version = [
          { role: "system", content: context.system_insts },
          { role: "user", content: context.simple_user_input },
        ]

        translated = context.system_user_scenario

        expect(translated).to eq(ollama_version)
      end
    end

    context "when native tool support is disabled - XML tools" do
      it "includes the instructions in the system message" do
        allow(model).to receive(:lookup_custom_param).with("enable_native_tool").and_return(false)

        DiscourseAi::Completions::Dialects::XmlTools
          .any_instance
          .stubs(:instructions)
          .returns("Instructions")

        ollama_version = [
          { role: "system", content: "#{context.system_insts}\n\nInstructions" },
          { role: "user", content: context.simple_user_input },
        ]

        translated = context.system_user_scenario

        expect(translated).to eq(ollama_version)
      end
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
      model.max_prompt_tokens = 10_000
      expect(context.dialect(nil).max_prompt_tokens).to eq(10_000)
    end
  end

  describe "#tools" do
    context "when native tools are enabled" do
      it "returns the translated tools from the OllamaTools class" do
        tool = instance_double(DiscourseAi::Completions::Dialects::OllamaTools)

        allow(model).to receive(:lookup_custom_param).with("enable_native_tool").and_return(true)
        allow(tool).to receive(:translated_tools)
        allow(DiscourseAi::Completions::Dialects::OllamaTools).to receive(:new).and_return(tool)

        context.dialect_tools

        expect(DiscourseAi::Completions::Dialects::OllamaTools).to have_received(:new).with(
          context.prompt.tools,
        )
        expect(tool).to have_received(:translated_tools)
      end
    end

    context "when native tools are disabled" do
      it "returns the translated tools from the XmlTools class" do
        tool = instance_double(DiscourseAi::Completions::Dialects::XmlTools)

        allow(model).to receive(:lookup_custom_param).with("enable_native_tool").and_return(false)
        allow(tool).to receive(:translated_tools)
        allow(DiscourseAi::Completions::Dialects::XmlTools).to receive(:new).and_return(tool)

        context.dialect_tools

        expect(DiscourseAi::Completions::Dialects::XmlTools).to have_received(:new).with(
          context.prompt.tools,
        )
        expect(tool).to have_received(:translated_tools)
      end
    end
  end
end
