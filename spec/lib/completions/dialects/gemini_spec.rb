# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Dialects::Gemini do
  subject(:dialect) { described_class.new(prompt, "gemini-pro") }

  let(:tool) do
    {
      name: "get_weather",
      description: "Get the weather in a city",
      parameters: [
        { name: "location", type: "string", description: "the city name", required: true },
        {
          name: "unit",
          type: "string",
          description: "the unit of measurement celcius c or fahrenheit f",
          enum: %w[c f],
          required: true,
        },
      ],
    }
  end

  let(:prompt) do
    {
      insts: <<~TEXT,
      I want you to act as a title generator for written pieces. I will provide you with a text,
      and you will generate five attention-grabbing titles. Please keep the title concise and under 20 words,
      and ensure that the meaning is maintained. Replies will utilize the language type of the topic.
    TEXT
      input: <<~TEXT,
      Here is the text, inside <input></input> XML tags:
      <input>
        To perfect his horror, Caesar, surrounded at the base of the statue by the impatient daggers of his friends,
        discovers among the faces and blades that of Marcus Brutus, his protege, perhaps his son, and he no longer
        defends himself, but instead exclaims: 'You too, my son!' Shakespeare and Quevedo capture the pathetic cry.

        Destiny favors repetitions, variants, symmetries; nineteen centuries later, in the southern province of Buenos Aires,
        a gaucho is attacked by other gauchos and, as he falls, recognizes a godson of his and says with gentle rebuke and
        slow surprise (these words must be heard, not read): 'But, my friend!' He is killed and does not know that he
        dies so that a scene may be repeated.
      </input>
    TEXT
      post_insts:
        "Please put the translation between <ai></ai> tags and separate each title with a comma.",
      tools: [tool],
    }
  end

  describe "#translate" do
    it "translates a prompt written in our generic format to the Gemini format" do
      gemini_version = [
        { role: "user", parts: { text: [prompt[:insts], prompt[:post_insts]].join("\n") } },
        { role: "model", parts: { text: "Ok." } },
        { role: "user", parts: { text: prompt[:input] } },
      ]

      translated = dialect.translate

      expect(translated).to eq(gemini_version)
    end

    it "include examples in the Gemini version" do
      prompt[:examples] = [
        [
          "<input>In the labyrinth of time, a solitary horse, etched in gold by the setting sun, embarked on an infinite journey.</input>",
          "<ai>The solitary horse.,The horse etched in gold.,A horse's infinite journey.,A horse lost in time.,A horse's last ride.</ai>",
        ],
      ]

      gemini_version = [
        { role: "user", parts: { text: [prompt[:insts], prompt[:post_insts]].join("\n") } },
        { role: "model", parts: { text: "Ok." } },
        { role: "user", parts: { text: prompt[:examples][0][0] } },
        { role: "model", parts: { text: prompt[:examples][0][1] } },
        { role: "user", parts: { text: prompt[:input] } },
      ]

      translated = dialect.translate

      expect(translated).to contain_exactly(*gemini_version)
    end
  end

  describe "#conversation_context" do
    let(:context) do
      [
        { type: "user", name: "user1", content: "This is a new message by a user" },
        { type: "assistant", content: "I'm a previous bot reply, that's why there's no user" },
        { type: "tool", name: "tool_id", content: "I'm a tool result" },
      ]
    end

    it "adds conversation in reverse order (first == newer)" do
      prompt[:conversation_context] = context

      translated_context = dialect.conversation_context

      expect(translated_context).to eq(
        [
          {
            role: "function",
            parts: {
              functionResponse: {
                name: context.last[:name],
                response: {
                  content: context.last[:content],
                },
              },
            },
          },
          { role: "model", parts: { text: context.second[:content] } },
          { role: "user", parts: { text: context.first[:content] } },
        ],
      )
    end

    it "trims content if it's getting too long" do
      context.last[:content] = context.last[:content] * 1000

      prompt[:conversation_context] = context

      translated_context = dialect.conversation_context

      expect(translated_context.last.dig(:parts, :text).length).to be <
        context.last[:content].length
    end

    context "when working with multi-turn contexts" do
      context "when the multi-turn is for turn that doesn't chain" do
        it "uses the tool_call context" do
          prompt[:conversation_context] = [
            {
              type: "multi_turn",
              content: [
                {
                  type: "tool_call",
                  name: "get_weather",
                  content: {
                    name: "get_weather",
                    arguments: {
                      location: "Sydney",
                      unit: "c",
                    },
                  }.to_json,
                },
                { type: "tool", name: "get_weather", content: "I'm a tool result" },
              ],
            },
          ]

          translated_context = dialect.conversation_context

          expected = [
            {
              role: "function",
              parts: {
                functionResponse: {
                  name: "get_weather",
                  response: {
                    content: "I'm a tool result",
                  },
                },
              },
            },
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
          ]

          expect(translated_context).to eq(expected)
        end
      end

      context "when the multi-turn is from a chainable tool" do
        it "uses the assistant context" do
          prompt[:conversation_context] = [
            {
              type: "multi_turn",
              content: [
                {
                  type: "tool_call",
                  name: "get_weather",
                  content: {
                    name: "get_weather",
                    arguments: {
                      location: "Sydney",
                      unit: "c",
                    },
                  }.to_json,
                },
                { type: "tool", name: "get_weather", content: "I'm a tool result" },
                { type: "assistant", content: "I'm a bot reply!" },
              ],
            },
          ]

          translated_context = dialect.conversation_context

          expected = [
            { role: "model", parts: { text: "I'm a bot reply!" } },
            {
              role: "function",
              parts: {
                functionResponse: {
                  name: "get_weather",
                  response: {
                    content: "I'm a tool result",
                  },
                },
              },
            },
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
          ]

          expect(translated_context).to eq(expected)
        end
      end
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

      expect(subject.tools).to contain_exactly(gemini_tools)
    end
  end
end
