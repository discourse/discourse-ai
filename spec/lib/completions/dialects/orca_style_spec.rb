# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Dialects::OrcaStyle do
  subject(:dialect) { described_class.new }

  describe "#translate" do
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

    it "translates a prompt written in our generic format to the Open AI format" do
      orca_style_version = <<~TEXT
      ### System:
      #{[prompt[:insts], prompt[:post_insts]].join("\n")}
      ### User:
      #{prompt[:input]}
      ### Assistant:
      TEXT

      translated = dialect.translate(prompt)

      expect(translated).to eq(orca_style_version)
    end

    it "include examples in the translated prompt" do
      prompt[:examples] = [
        [
          "<input>In the labyrinth of time, a solitary horse, etched in gold by the setting sun, embarked on an infinite journey.</input>",
          "<ai>The solitary horse.,The horse etched in gold.,A horse's infinite journey.,A horse lost in time.,A horse's last ride.</ai>",
        ],
      ]

      orca_style_version = <<~TEXT
      ### System:
      #{[prompt[:insts], prompt[:post_insts]].join("\n")}
      ### User:
      #{prompt[:examples][0][0]}
      ### Assistant:
      #{prompt[:examples][0][1]}
      ### User:
      #{prompt[:input]}
      ### Assistant:
      TEXT

      translated = dialect.translate(prompt)

      expect(translated).to eq(orca_style_version)
    end
  end
end
