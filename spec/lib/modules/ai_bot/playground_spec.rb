# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Playground do
  subject(:playground) { described_class.new(bot) }

  before do
    SiteSetting.ai_bot_enabled_chat_bots = "claude-2"
    SiteSetting.ai_bot_enabled = true
  end

  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::CLAUDE_V2_ID) }
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

        reply = pm.reload.posts.last

        noop_signal = messages.pop
        expect(noop_signal.data[:noop]).to eq(true)

        done_signal = messages.pop
        expect(done_signal.data[:done]).to eq(true)
        expect(done_signal.data[:cooked]).to eq(reply.cooked)

        expect(messages.first.data[:raw]).to eq("")
        messages[1..-1].each_with_index do |m, idx|
          expect(m.data[:raw]).to eq(expected_bot_response[0..idx])
        end

        expect(reply.cooked).to eq(PrettyText.cook(expected_bot_response))
      end
    end

    it "does not include placeholders in conversation context but includes all completions" do
      response1 = (<<~TXT).strip
          <function_calls>
          <invoke>
          <tool_name>search</tool_name>
          <tool_id>search</tool_id>
          <parameters>
          <search_query>testing various things</search_query>
          </parameters>
          </invoke>
          </function_calls>
       TXT

      response2 = "I found some really amazing stuff!"

      DiscourseAi::Completions::Llm.with_prepared_responses([response1, response2]) do
        playground.reply_to(third_post)
      end

      last_post = third_post.topic.reload.posts.order(:post_number).last
      custom_prompt = PostCustomPrompt.where(post_id: last_post.id).first.custom_prompt

      expect(custom_prompt.length).to eq(3)
      expect(custom_prompt.to_s).not_to include("<details>")
      expect(custom_prompt.last.first).to eq(response2)
      expect(custom_prompt.last.last).to eq(bot_user.username)
    end

    context "with Dall E bot" do
      let(:bot) do
        DiscourseAi::AiBot::Bot.as(bot_user, persona: DiscourseAi::AiBot::Personas::DallE3.new)
      end

      it "does not include placeholders in conversation context (simulate DALL-E)" do
        SiteSetting.ai_openai_api_key = "123"

        response = (<<~TXT).strip
          <function_calls>
          <invoke>
          <tool_name>dall_e</tool_name>
          <tool_id>dall_e</tool_id>
          <parameters>
          <prompts>["a pink cow"]</prompts>
          </parameters>
          </invoke>
          </function_calls>
       TXT

        image =
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="

        data = [{ b64_json: image, revised_prompt: "a pink cow 1" }]

        WebMock.stub_request(:post, SiteSetting.ai_openai_dall_e_3_url).to_return(
          status: 200,
          body: { data: data }.to_json,
        )

        DiscourseAi::Completions::Llm.with_prepared_responses([response]) do
          playground.reply_to(third_post)
        end

        last_post = third_post.topic.reload.posts.order(:post_number).last
        custom_prompt = PostCustomPrompt.where(post_id: last_post.id).first.custom_prompt

        # DALL E has custom_raw, we do not want to inject this into the prompt stream
        expect(custom_prompt.length).to eq(2)
        expect(custom_prompt.to_s).not_to include("<details>")
      end
    end
  end

  describe "#conversation_context" do
    it "includes previous posts ordered by post_number" do
      context = playground.conversation_context(third_post)

      expect(context).to contain_exactly(
        *[
          { type: :user, id: user.username, content: third_post.raw },
          { type: :model, content: second_post.raw },
          { type: :user, id: user.username, content: first_post.raw },
        ],
      )
    end

    it "only include regular posts" do
      first_post.update!(post_type: Post.types[:whisper])

      context = playground.conversation_context(third_post)

      expect(context).to contain_exactly(
        *[
          { type: :user, id: user.username, content: third_post.raw },
          { type: :model, content: second_post.raw },
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
            { type: :user, id: user.username, content: third_post.raw },
            { type: :model, content: custom_prompt.third.first },
            { type: :tool_call, content: custom_prompt.second.first, id: "time" },
            { type: :tool, id: "time", content: custom_prompt.first.first },
            { type: :user, id: user.username, content: first_post.raw },
          ],
        )
      end

      it "include replies generated from tools only once" do
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
        PostCustomPrompt.create!(post: first_post, custom_prompt: custom_prompt)

        context = playground.conversation_context(third_post)

        expect(context).to contain_exactly(
          *[
            { type: :user, id: user.username, content: third_post.raw },
            { type: :model, content: custom_prompt.third.first },
            { type: :tool_call, content: custom_prompt.second.first, id: "time" },
            { type: :tool, id: "time", content: custom_prompt.first.first },
            { type: :tool_call, content: custom_prompt.second.first, id: "time" },
            { type: :tool, id: "time", content: custom_prompt.first.first },
          ],
        )
      end
    end
  end
end
