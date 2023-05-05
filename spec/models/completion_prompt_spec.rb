# frozen_string_literal: true

RSpec.describe CompletionPrompt do
  describe "validations" do
    context "when there are too many messages" do
      it "doesn't accept more than 20 messages" do
        prompt = described_class.new(messages: [{ role: "system", content: "a" }] * 21)

        expect(prompt.valid?).to eq(false)
      end
    end

    context "when the message is over the max length" do
      it "doesn't accept messages when the length is more than 1000 characters" do
        prompt = described_class.new(messages: [{ role: "system", content: "a" * 1001 }])

        expect(prompt.valid?).to eq(false)
      end
    end
  end

  describe ".bot_prompt_with_topic_context" do
    fab!(:topic) { Fabricate(:topic) }

    def post_body(post_number)
      "This is post #{post_number}"
    end

    context "when the topic has one post" do
      fab!(:post_1) { Fabricate(:post, topic: topic, raw: post_body(1), post_number: 1) }

      it "includes it in the prompt" do
        prompt_messages = described_class.bot_prompt_with_topic_context(post_1)

        post_1_message = prompt_messages[1]

        expect(post_1_message[:role]).to eq("user")
        expect(post_1_message[:content]).to eq(post_body(1))
      end
    end

    context "when the topic has multiple posts" do
      fab!(:post_1) { Fabricate(:post, topic: topic, raw: post_body(1), post_number: 1) }
      fab!(:post_2) do
        Fabricate(:post, topic: topic, user: Discourse.gpt_bot, raw: post_body(2), post_number: 2)
      end
      fab!(:post_3) { Fabricate(:post, topic: topic, raw: post_body(3), post_number: 3) }

      it "includes them in the prompt respecting the post number order" do
        prompt_messages = described_class.bot_prompt_with_topic_context(post_3)

        expect(prompt_messages[1][:role]).to eq("user")
        expect(prompt_messages[1][:content]).to eq(post_body(1))

        expect(prompt_messages[2][:role]).to eq("system")
        expect(prompt_messages[2][:content]).to eq(post_body(2))

        expect(prompt_messages[3][:role]).to eq("user")
        expect(prompt_messages[3][:content]).to eq(post_body(3))
      end
    end
  end
end
