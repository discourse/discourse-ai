# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Llm do
  subject(:llm) do
    described_class.new(
      DiscourseAi::Completions::Dialects::OrcaStyle,
      canned_response,
      "Upstage-Llama-2-*-instruct-v2",
    )
  end

  fab!(:user) { Fabricate(:user) }

  describe ".proxy" do
    it "raises an exception when we can't proxy the model" do
      fake_model = "unknown_v2"

      expect { described_class.proxy(fake_model) }.to(
        raise_error(DiscourseAi::Completions::Llm::UNKNOWN_MODEL),
      )
    end
  end

  describe "#generate with fake model" do
    before do
      DiscourseAi::Completions::Endpoints::Fake.delays = []
      DiscourseAi::Completions::Endpoints::Fake.chunk_count = 10
    end

    let(:llm) { described_class.proxy("fake") }

    let(:prompt) do
      DiscourseAi::Completions::Prompt.new(
        "You are fake",
        messages: [{ type: :user, content: "fake orders" }],
      )
    end

    it "can generate a response" do
      response = llm.generate(prompt, user: user)
      expect(response).to be_present
    end

    it "can generate content via a block" do
      partials = []
      response = llm.generate(prompt, user: user) { |partial| partials << partial }

      expect(partials.length).to eq(10)
      expect(response).to eq(DiscourseAi::Completions::Endpoints::Fake.fake_content)

      expect(partials.join).to eq(response)
    end
  end

  describe "#generate" do
    let(:prompt) do
      system_insts = (<<~TEXT).strip
      I want you to act as a title generator for written pieces. I will provide you with a text,
      and you will generate five attention-grabbing titles. Please keep the title concise and under 20 words,
      and ensure that the meaning is maintained. Replies will utilize the language type of the topic.
      TEXT

      DiscourseAi::Completions::Prompt
        .new(system_insts)
        .tap { |a_prompt| a_prompt.push(type: :user, content: (<<~TEXT).strip) }
          Here is the text, inside <input></input> XML tags:
          <input>
            To perfect his horror, Caesar, surrounded at the base of the statue by the impatient daggers of his friends,
            discovers among the faces and blades that of Marcus Brutus, his protege, perhaps his son, and he no longer
            defends himself, but instead exclaims: 'You too, my son!' Shakespeare and Quevedo capture the pathetic cry.
          </input>
          TEXT
    end

    let(:canned_response) do
      DiscourseAi::Completions::Endpoints::CannedResponse.new(
        [
          "<ai>The solitary horse.,The horse etched in gold.,A horse's infinite journey.,A horse lost in time.,A horse's last ride.</ai>",
        ],
      )
    end

    context "when getting the full response" do
      it "processes the prompt and return the response" do
        llm_response = llm.generate(prompt, user: user)

        expect(llm_response).to eq(canned_response.responses[0])
      end
    end

    context "when getting a streamed response" do
      it "processes the prompt and call the given block with the partial response" do
        llm_response = +""

        llm.generate(prompt, user: user) { |partial, cancel_fn| llm_response << partial }

        expect(llm_response).to eq(canned_response.responses[0])
      end
    end
  end
end
