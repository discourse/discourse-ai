# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Dialects::Claude do
  subject(:dialect) { described_class.new(prompt, "claude-2") }

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
    }
  end

  describe "#translate" do
    it "translates a prompt written in our generic format to Claude's format" do
      anthropic_version = <<~TEXT
      #{prompt[:insts]}
      #{prompt[:input]}
      #{prompt[:post_insts]}


      Assistant:
      TEXT

      translated = dialect.translate

      expect(translated).to eq(anthropic_version)
    end

    it "knows how to translate examples to Claude's format" do
      prompt[:examples] = [
        [
          "<input>In the labyrinth of time, a solitary horse, etched in gold by the setting sun, embarked on an infinite journey.</input>",
          "<ai>The solitary horse.,The horse etched in gold.,A horse's infinite journey.,A horse lost in time.,A horse's last ride.</ai>",
        ],
      ]
      anthropic_version = <<~TEXT
      #{prompt[:insts]}
      <example>
      H: #{prompt[:examples][0][0]}
      A: #{prompt[:examples][0][1]}
      </example>
      #{prompt[:input]}
      #{prompt[:post_insts]}


      Assistant:
      TEXT

      translated = dialect.translate

      expect(translated).to eq(anthropic_version)
    end

    it "include tools inside the prompt" do
      prompt[:tools] = [tool]

      anthropic_version = <<~TEXT
      #{prompt[:insts]}
      #{DiscourseAi::Completions::Dialects::Claude.tool_preamble}
      <tools>
      #{dialect.tools}</tools>
      #{prompt[:input]}
      #{prompt[:post_insts]}


      Assistant:
      TEXT

      translated = dialect.translate

      expect(translated).to eq(anthropic_version)
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

      expected = <<~TEXT
      Assistant:
      <function_results>
      <result>
      <tool_name>tool_id</tool_name>
      <json>
      #{context.last[:content]}
      </json>
      </result>
      </function_results>
      Assistant: #{context.second[:content]}
      Human: #{context.first[:content]}
      TEXT

      translated_context = dialect.conversation_context

      expect(translated_context).to eq(expected)
    end

    it "trims content if it's getting too long" do
      context.last[:content] = context.last[:content] * 10_000
      prompt[:conversation_context] = context

      translated_context = dialect.conversation_context

      expect(translated_context.length).to be < context.last[:content].length
    end
  end

  describe "#tools" do
    it "translates tools to the tool syntax" do
      prompt[:tools] = [tool]

      translated_tool = <<~TEXT
        <tool_description>
        <tool_name>get_weather</tool_name>
        <description>Get the weather in a city</description>
        <parameters>
        <parameter>
        <name>location</name>
        <type>string</type>
        <description>the city name</description>
        <required>true</required>
        </parameter>
        <parameter>
        <name>unit</name>
        <type>string</type>
        <description>the unit of measurement celcius c or fahrenheit f</description>
        <required>true</required>
        <options>c,f</options>
        </parameter>
        </parameters>
        </tool_description>
      TEXT

      expect(dialect.tools).to eq(translated_tool)
    end
  end
end
