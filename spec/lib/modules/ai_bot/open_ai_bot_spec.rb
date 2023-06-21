# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::OpenAiBot do
  describe "#bot_prompt_with_topic_context" do
    fab!(:topic) { Fabricate(:topic) }

    def post_body(post_number)
      "This is post #{post_number}"
    end

    def bot_user
      User.find(DiscourseAi::AiBot::EntryPoint::GPT4_ID)
    end

    subject { described_class.new(bot_user) }

    context "when changing avialable commands" do
      it "contains all commands by default" do
        # this will break as we add commands, but it is important as a sanity check
        SiteSetting.ai_stability_api_key = "test"
        SiteSetting.ai_google_custom_search_api_key = "test"
        SiteSetting.ai_google_custom_search_cx = "test"

        expect(subject.available_commands.length).to eq(6)
        expect(subject.available_commands.length).to eq(
          SiteSetting.ai_bot_enabled_chat_commands.split("|").length,
        )
      end
      it "can properly filter out commands" do
        SiteSetting.ai_bot_enabled_chat_commands = "time|tags"
        expect(subject.available_commands.length).to eq(2)
        expect(subject.available_commands).to eq(
          [DiscourseAi::AiBot::Commands::TimeCommand, DiscourseAi::AiBot::Commands::TagsCommand],
        )
      end
    end

    context "when cleaning usernames" do
      it "can properly clean usernames so OpenAI allows it" do
        subject.clean_username("test test").should eq("test_test")
        subject.clean_username("test.test").should eq("test_test")
        subject.clean_username("test😀test").should eq("test_test")
      end
    end

    context "when the topic has one post" do
      fab!(:post_1) { Fabricate(:post, topic: topic, raw: post_body(1), post_number: 1) }

      it "includes it in the prompt" do
        prompt_messages = subject.bot_prompt_with_topic_context(post_1)

        post_1_message = prompt_messages[-1]

        expect(post_1_message[:role]).to eq("user")
        expect(post_1_message[:content]).to eq(post_body(1))
        expect(post_1_message[:name]).to eq(post_1.user.username)
      end
    end

    context "when prompt gets very long" do
      fab!(:post_1) { Fabricate(:post, topic: topic, raw: "test " * 6000, post_number: 1) }

      it "trims the prompt" do
        prompt_messages = subject.bot_prompt_with_topic_context(post_1)

        # trimming is tricky... it needs to account for system message as
        # well... just make sure we trim for now
        expect(prompt_messages[-1][:content].length).to be < post_1.raw.length
      end
    end

    context "when the topic has multiple posts" do
      fab!(:post_1) { Fabricate(:post, topic: topic, raw: post_body(1), post_number: 1) }
      fab!(:post_2) do
        Fabricate(:post, topic: topic, user: bot_user, raw: post_body(2), post_number: 2)
      end
      fab!(:post_3) { Fabricate(:post, topic: topic, raw: post_body(3), post_number: 3) }

      it "includes them in the prompt respecting the post number order" do
        prompt_messages = subject.bot_prompt_with_topic_context(post_3)

        # negative cause we may have grounding prompts
        expect(prompt_messages[-3][:role]).to eq("user")
        expect(prompt_messages[-3][:content]).to eq(post_body(1))
        expect(prompt_messages[-3][:name]).to eq(post_1.username)

        expect(prompt_messages[-2][:role]).to eq("assistant")
        expect(prompt_messages[-2][:content]).to eq(post_body(2))

        expect(prompt_messages[-1][:role]).to eq("user")
        expect(prompt_messages[-1][:content]).to eq(post_body(3))
        expect(prompt_messages[-1][:name]).to eq(post_3.username)
      end
    end
  end
end
