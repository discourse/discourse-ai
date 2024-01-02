# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Dialects::ChatGpt do
  subject(:dialect) { described_class.new(prompt, "gpt-4") }

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
    it "translates a prompt written in our generic format to the ChatGPT format" do
      open_ai_version = [
        { role: "system", content: [prompt[:insts], prompt[:post_insts]].join("\n") },
        { role: "user", content: prompt[:input] },
      ]

      translated = dialect.translate

      expect(translated).to contain_exactly(*open_ai_version)
    end

    it "include examples in the ChatGPT version" do
      prompt[:examples] = [
        [
          "<input>In the labyrinth of time, a solitary horse, etched in gold by the setting sun, embarked on an infinite journey.</input>",
          "<ai>The solitary horse.,The horse etched in gold.,A horse's infinite journey.,A horse lost in time.,A horse's last ride.</ai>",
        ],
      ]

      open_ai_version = [
        { role: "system", content: [prompt[:insts], prompt[:post_insts]].join("\n") },
        { role: "user", content: prompt[:examples][0][0] },
        { role: "assistant", content: prompt[:examples][0][1] },
        { role: "user", content: prompt[:input] },
      ]

      translated = dialect.translate

      expect(translated).to contain_exactly(*open_ai_version)
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
          { role: "tool", content: context.last[:content], tool_call_id: context.last[:name] },
          { role: "assistant", content: context.second[:content] },
          { role: "user", content: context.first[:content], name: context.first[:name] },
        ],
      )
    end

    it "trims content if it's getting too long" do
      context.last[:content] = context.last[:content] * 1000

      prompt[:conversation_context] = context

      translated_context = dialect.conversation_context

      expect(translated_context.last[:content].length).to be < context.last[:content].length
    end
  end

  describe "#tools" do
    it "returns a list of available tools" do
      open_ai_tool_f = {
        function: {
          description: tool[:description],
          name: tool[:name],
          parameters: {
            properties:
              tool[:parameters].reduce({}) do |memo, p|
                memo[p[:name]] = { description: p[:description], type: p[:type] }

                memo[p[:name]][:enum] = p[:enum] if p[:enum]

                memo
              end,
            required: %w[location unit],
            type: "object",
          },
        },
        type: "function",
      }

      expect(subject.tools).to contain_exactly(open_ai_tool_f)
    end
  end
end
