# frozen_string_literal: true

require_relative "dialect_context"

RSpec.describe DiscourseAi::Completions::Dialects::Gemini do
  let(:model_name) { "gemini-pro" }
  let(:context) { DialectContext.new(described_class, model_name) }

  describe "#translate" do
    it "translates a prompt written in our generic format to the Gemini format" do
      gemini_version = [
        { role: "user", parts: { text: context.system_insts } },
        { role: "model", parts: { text: "Ok." } },
        { role: "user", parts: { text: context.simple_user_input } },
      ]

      translated = context.system_user_scenario

      expect(translated).to eq(gemini_version)
    end

    it "injects model after tool call" do
      expect(context.image_generation_scenario).to eq(
        [
          { role: "user", parts: { text: context.system_insts } },
          { parts: { text: "Ok." }, role: "model" },
          { parts: { text: "draw a cat" }, role: "user" },
          { parts: { functionCall: { args: { picture: "Cat" }, name: "draw" } }, role: "model" },
          {
            parts: {
              functionResponse: {
                name: "tool_id",
                response: {
                  content: "\"I'm a tool result\"",
                },
              },
            },
            role: "function",
          },
          { parts: { text: "Ok." }, role: "model" },
          { parts: { text: "draw another cat" }, role: "user" },
        ],
      )
    end

    it "translates tool_call and tool messages" do
      expect(context.multi_turn_scenario).to eq(
        [
          { role: "user", parts: { text: context.system_insts } },
          { role: "model", parts: { text: "Ok." } },
          { role: "user", parts: { text: "This is a message by a user" } },
          {
            role: "model",
            parts: {
              text: "I'm a previous bot reply, that's why there's no user",
            },
          },
          { role: "user", parts: { text: "This is a new message by a user" } },
          {
            role: "model",
            parts: {
              functionCall: {
                name: "get_weather",
                args: {
                  location: "Sydney",
                  unit: "c",
                },
              },
            },
          },
          {
            role: "function",
            parts: {
              functionResponse: {
                name: "get_weather",
                response: {
                  content: "I'm a tool result".to_json,
                },
              },
            },
          },
        ],
      )
    end

    it "trims content if it's getting too long" do
      translated = context.long_user_input_scenario(length: 5_000)

      expect(translated.last[:role]).to eq("user")
      expect(translated.last.dig(:parts, :text).length).to be <
        context.long_message_text(length: 5_000).length
    end
  end

  describe "#tools" do
    it "returns a list of available tools" do
      gemini_tools = {
        function_declarations: [
          {
            name: "get_weather",
            description: "Get the weather in a city",
            parameters: {
              type: "object",
              required: %w[location unit],
              properties: {
                "location" => {
                  type: "string",
                  description: "the city name",
                },
                "unit" => {
                  type: "string",
                  description: "the unit of measurement celcius c or fahrenheit f",
                  enum: %w[c f],
                },
              },
            },
          },
        ],
      }

      expect(context.dialect_tools).to contain_exactly(gemini_tools)
    end
  end
end
