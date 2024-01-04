# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Playground do
  subject(:playground) { described_class.new(bot) }

  before do
    SiteSetting.ai_bot_enabled_chat_bots = "gpt-4"
    SiteSetting.ai_bot_enabled = true
  end

  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT4_ID) }
  let(:bot) { DiscourseAi::AiBot::Bot.as(bot_user) }

  fab!(:user) { Fabricate(:user) }
  let!(:pm) do
    Fabricate(
      :private_message_topic,
      title: "This is my special PM",
      user: user,
      topic_allowed_users: [
        Fabricate.build(:topic_allowed_user, user: user),
        Fabricate.build(:topic_allowed_user, user: bot_user),
      ],
    )
  end
  let!(:first_post) do
    Fabricate(:post, topic: pm, user: user, post_number: 1, raw: "This is a reply by the user")
  end
  let!(:second_post) do
    Fabricate(:post, topic: pm, user: bot_user, post_number: 2, raw: "This is a bot reply")
  end
  let!(:third_post) do
    Fabricate(
      :post,
      topic: pm,
      user: user,
      post_number: 3,
      raw: "This is a second reply by the user",
    )
  end

  describe "#title_playground" do
    let(:expected_response) { "This is a suggested title" }

    before { SiteSetting.min_personal_message_post_length = 5 }

    it "updates the title using bot suggestions" do
      DiscourseAi::Completions::Llm.with_prepared_responses([expected_response]) do
        playground.title_playground(third_post)

        expect(pm.reload.title).to eq(expected_response)
      end
    end
  end

  describe "#reply_to" do
    it "streams the bot reply through MB and create a new post in the PM with a cooked responses" do
      expected_bot_response =
        "Hello this is a bot and what you just said is an interesting question"

      DiscourseAi::Completions::Llm.with_prepared_responses([expected_bot_response]) do
        messages =
          MessageBus.track_publish("discourse-ai/ai-bot/topic/#{pm.id}") do
            playground.reply_to(third_post)
          end

        done_signal = messages.pop
        expect(done_signal.data[:done]).to eq(true)

        messages.each_with_index do |m, idx|
          expect(m.data[:raw]).to eq(expected_bot_response[0..idx])
        end

        expect(pm.reload.posts.last.cooked).to eq(PrettyText.cook(expected_bot_response))
      end
    end
  end

  describe "#conversation_context" do
    it "includes previous posts ordered by post_number" do
      context = playground.conversation_context(third_post)

      expect(context).to contain_exactly(
        *[
          { type: "user", name: user.username, content: third_post.raw },
          { type: "assistant", content: second_post.raw },
          { type: "user", name: user.username, content: first_post.raw },
        ],
      )
    end

    it "only include regular posts" do
      first_post.update!(post_type: Post.types[:whisper])

      context = playground.conversation_context(third_post)

      expect(context).to contain_exactly(
        *[
          { type: "user", name: user.username, content: third_post.raw },
          { type: "assistant", content: second_post.raw },
        ],
      )
    end

    context "with custom prompts" do
      it "When post custom prompt is present, we use that instead of the post content" do
        custom_prompt = [
          [
            { args: { timezone: "Buenos Aires" }, time: "2023-12-14 17:24:00 -0300" }.to_json,
            "time",
            "tool",
          ],
          [
            { name: "time", arguments: { name: "time", timezone: "Buenos Aires" } }.to_json,
            "time",
            "tool_call",
          ],
          ["I replied this thanks to the time command", bot_user.username],
        ]

        PostCustomPrompt.create!(post: second_post, custom_prompt: custom_prompt)

        context = playground.conversation_context(third_post)

        expect(context).to contain_exactly(
          *[
            { type: "user", name: user.username, content: third_post.raw },
            {
              type: "multi_turn",
              content: [
                { type: "assistant", content: custom_prompt.third.first },
                { type: "tool_call", content: custom_prompt.second.first, name: "time" },
                { type: "tool", name: "time", content: custom_prompt.first.first },
              ],
            },
            { type: "user", name: user.username, content: first_post.raw },
          ],
        )
      end
    end
  end
end
