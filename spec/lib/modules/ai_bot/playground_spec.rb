# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Playground do
  subject(:playground) { described_class.new(bot) }

  fab!(:bot_user) do
    SiteSetting.ai_bot_enabled_chat_bots = "claude-2"
    SiteSetting.ai_bot_enabled = true
    User.find(DiscourseAi::AiBot::EntryPoint::CLAUDE_V2_ID)
  end

  fab!(:bot) do
    persona =
      AiPersona
        .find(
          DiscourseAi::AiBot::Personas::Persona.system_personas[
            DiscourseAi::AiBot::Personas::General
          ],
        )
        .class_instance
        .new
    DiscourseAi::AiBot::Bot.as(bot_user, persona: persona)
  end

  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:pm) do
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
  fab!(:first_post) do
    Fabricate(:post, topic: pm, user: user, post_number: 1, raw: "This is a reply by the user")
  end
  fab!(:second_post) do
    Fabricate(:post, topic: pm, user: bot_user, post_number: 2, raw: "This is a bot reply")
  end
  fab!(:third_post) do
    Fabricate(
      :post,
      topic: pm,
      user: user,
      post_number: 3,
      raw: "This is a second reply by the user",
    )
  end

  describe "is_bot_user_id?" do
    it "properly detects ALL bots as bot users" do
      persona = Fabricate(:ai_persona, enabled: false)
      persona.create_user!

      expect(DiscourseAi::AiBot::Playground.is_bot_user_id?(persona.user_id)).to eq(true)
    end
  end

  describe "image support" do
    before do
      Jobs.run_immediately!
      SiteSetting.ai_bot_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_0]}"
    end

    fab!(:persona) do
      AiPersona.create!(
        name: "Test Persona",
        description: "A test persona",
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        enabled: true,
        system_prompt: "You are a helpful bot",
        vision_enabled: true,
        vision_max_pixels: 1_000,
        default_llm: "anthropic:claude-3-opus",
        mentionable: true,
      )
    end

    fab!(:upload)

    it "sends images to llm" do
      post = nil

      persona.create_user!

      image = "![image](upload://#{upload.base62_sha1}.jpg)"
      body = "Hey @#{persona.user.username}, can you help me with this image? #{image}"

      prompts = nil
      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["I understood image"],
      ) do |_, _, inner_prompts|
        post = create_post(title: "some new topic I created", raw: body)

        prompts = inner_prompts
      end

      expect(prompts[0].messages[1][:upload_ids]).to eq([upload.id])
      expect(prompts[0].max_pixels).to eq(1000)

      post.topic.reload
      last_post = post.topic.posts.order(:post_number).last

      expect(last_post.raw).to eq("I understood image")
    end
  end

  describe "persona with user support" do
    before do
      Jobs.run_immediately!
      SiteSetting.ai_bot_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_0]}"
    end

    fab!(:persona) do
      persona =
        AiPersona.create!(
          name: "Test Persona",
          description: "A test persona",
          allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
          enabled: true,
          system_prompt: "You are a helpful bot",
        )

      persona.create_user!
      persona.update!(default_llm: "anthropic:claude-2", mentionable: true)
      persona
    end

    context "with chat channels" do
      fab!(:channel) { Fabricate(:chat_channel) }

      fab!(:membership) do
        Fabricate(:user_chat_channel_membership, user: user, chat_channel: channel)
      end

      let(:guardian) { Guardian.new(user) }

      before do
        SiteSetting.ai_bot_enabled = true
        SiteSetting.chat_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_0]}"
        Group.refresh_automatic_groups!
        persona.update!(allow_chat: true, mentionable: true, default_llm: "anthropic:claude-3-opus")
      end

      it "should reply to a mention if properly enabled" do
        prompts = nil

        ChatSDK::Message.create(
          channel_id: channel.id,
          raw: "This is a story about stuff",
          guardian: guardian,
        )

        DiscourseAi::Completions::Llm.with_prepared_responses(["world"]) do |_, _, _prompts|
          ChatSDK::Message.create(
            channel_id: channel.id,
            raw: "Hello @#{persona.user.username}",
            guardian: guardian,
          )

          prompts = _prompts
        end

        expect(prompts.length).to eq(1)
        prompt = prompts[0]

        expect(prompt.messages.length).to eq(2)
        expect(prompt.messages[1][:content]).to include("story about stuff")
        expect(prompt.messages[1][:content]).to include("Hello")

        last_message = Chat::Message.where(chat_channel_id: channel.id).order("id desc").first
        expect(last_message.message).to eq("world")
      end
    end

    context "with chat dms" do
      fab!(:dm_channel) { Fabricate(:direct_message_channel, users: [user, persona.user]) }

      before do
        SiteSetting.chat_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_0]}"
        Group.refresh_automatic_groups!
        persona.update!(
          allow_chat: true,
          mentionable: false,
          default_llm: "anthropic:claude-3-opus",
        )
        SiteSetting.ai_bot_enabled = true
      end

      let(:guardian) { Guardian.new(user) }

      it "can run tools" do
        persona.update!(commands: ["TimeCommand"])

        responses = [
          "<function_calls><invoke><tool_name>time</tool_name><tool_id>time</tool_id><parameters><timezone>Buenos Aires</timezone></parameters></invoke></function_calls>",
          "The time is 2023-12-14 17:24:00 -0300",
        ]

        message =
          DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
            ChatSDK::Message.create(channel_id: dm_channel.id, raw: "Hello", guardian: guardian)
          end

        message.reload
        expect(message.thread_id).to be_present
        reply = ChatSDK::Thread.messages(thread_id: message.thread_id, guardian: guardian).last

        expect(reply.message).to eq("The time is 2023-12-14 17:24:00 -0300")

        # it also needs to have tool details now set on message
        prompt = ChatMessageCustomPrompt.find_by(message_id: reply.id)
        expect(prompt.custom_prompt.length).to eq(3)

        # TODO in chat I am mixed on including this in the context, but I guess maybe?
        # thinking about this
      end

      it "can reply to a chat message" do
        message =
          DiscourseAi::Completions::Llm.with_prepared_responses(["World"]) do
            ChatSDK::Message.create(channel_id: dm_channel.id, raw: "Hello", guardian: guardian)
          end

        message.reload
        expect(message.thread_id).to be_present

        thread_messages = ChatSDK::Thread.messages(thread_id: message.thread_id, guardian: guardian)
        expect(thread_messages.length).to eq(2)
        expect(thread_messages.last.message).to eq("World")

        # it also needs to include history per config - first feed some history
        persona.update!(enabled: false)

        persona_guardian = Guardian.new(persona.user)

        4.times do |i|
          ChatSDK::Message.create(
            channel_id: dm_channel.id,
            thread_id: message.thread_id,
            raw: "request #{i}",
            guardian: guardian,
          )

          ChatSDK::Message.create(
            channel_id: dm_channel.id,
            thread_id: message.thread_id,
            raw: "response #{i}",
            guardian: persona_guardian,
          )
        end

        persona.update!(max_context_posts: 4, enabled: true)

        prompts = nil
        DiscourseAi::Completions::Llm.with_prepared_responses(
          ["World 2"],
        ) do |_response, _llm, _prompts|
          ChatSDK::Message.create(
            channel_id: dm_channel.id,
            thread_id: message.thread_id,
            raw: "Hello",
            guardian: guardian,
          )
          prompts = _prompts
        end

        expect(prompts.length).to eq(1)

        mapped =
          prompts[0]
            .messages
            .map { |m| "#{m[:type]}: #{m[:content]}" if m[:type] != :system }
            .compact
            .join("\n")
            .strip

        # why?
        # 1. we set context to 4
        # 2. however PromptMessagesBuilder will enforce rules of starting with :user and ending with it
        # so one of the model messages is dropped
        expected = (<<~TEXT).strip
          user: request 3
          model: response 3
          user: Hello
        TEXT

        expect(mapped).to eq(expected)
      end
    end

    it "replies to whispers with a whisper" do
      post = nil
      DiscourseAi::Completions::Llm.with_prepared_responses(["Yes I can"]) do
        post =
          create_post(
            title: "My public topic",
            raw: "Hey @#{persona.user.username}, can you help me?",
            post_type: Post.types[:whisper],
          )
      end

      post.topic.reload
      last_post = post.topic.posts.order(:post_number).last
      expect(last_post.raw).to eq("Yes I can")
      expect(last_post.user_id).to eq(persona.user_id)
      expect(last_post.post_type).to eq(Post.types[:whisper])
    end

    it "allows mentioning a persona" do
      # we still should be able to mention with no bots
      SiteSetting.ai_bot_enabled_chat_bots = ""

      post = nil
      DiscourseAi::Completions::Llm.with_prepared_responses(["Yes I can"]) do
        post =
          create_post(
            title: "My public topic",
            raw: "Hey @#{persona.user.username}, can you help me?",
          )
      end

      post.topic.reload
      last_post = post.topic.posts.order(:post_number).last
      expect(last_post.raw).to eq("Yes I can")
      expect(last_post.user_id).to eq(persona.user_id)
    end

    it "allows PMing a persona even when no particular bots are enabled" do
      SiteSetting.ai_bot_enabled = true
      SiteSetting.ai_bot_enabled_chat_bots = ""
      post = nil

      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["Magic title", "Yes I can"],
        llm: "anthropic:claude-2",
      ) do
        post =
          create_post(
            title: "I just made a PM",
            raw: "Hey there #{persona.user.username}, can you help me?",
            target_usernames: "#{user.username},#{persona.user.username}",
            archetype: Archetype.private_message,
            user: admin,
          )
      end

      last_post = post.topic.posts.order(:post_number).last
      expect(last_post.raw).to eq("Yes I can")
      expect(last_post.user_id).to eq(persona.user_id)

      last_post.topic.reload
      expect(last_post.topic.allowed_users.pluck(:user_id)).to include(persona.user_id)

      expect(last_post.topic.participant_count).to eq(2)
    end

    it "picks the correct llm for persona in PMs" do
      # If you start a PM with GPT 3.5 bot, replies should come from it, not from Claude
      SiteSetting.ai_bot_enabled = true
      SiteSetting.ai_bot_enabled_chat_bots = "gpt-3.5-turbo|claude-2"

      post = nil
      gpt3_5_bot_user = User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID)

      # title is queued first, ensures it uses the llm targeted via target_usernames not claude
      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["Magic title", "Yes I can"],
        llm: "open_ai:gpt-3.5-turbo-16k",
      ) do
        post =
          create_post(
            title: "I just made a PM",
            raw: "Hey @#{persona.user.username}, can you help me?",
            target_usernames: "#{user.username},#{gpt3_5_bot_user.username}",
            archetype: Archetype.private_message,
            user: admin,
          )
      end

      last_post = post.topic.posts.order(:post_number).last
      expect(last_post.raw).to eq("Yes I can")
      expect(last_post.user_id).to eq(persona.user_id)

      last_post.topic.reload
      expect(last_post.topic.allowed_users.pluck(:user_id)).to include(persona.user_id)

      # does not reply if replying directly to a user
      # nothing is mocked, so this would result in HTTP error
      # if we were going to reply
      create_post(
        raw: "Please ignore this bot, I am replying to a user",
        topic: post.topic,
        user: admin,
        reply_to_post_number: post.post_number,
      )

      # replies as correct persona if replying direct to persona
      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["Another reply"],
        llm: "open_ai:gpt-3.5-turbo-16k",
      ) do
        create_post(
          raw: "Please ignore this bot, I am replying to a user",
          topic: post.topic,
          user: admin,
          reply_to_post_number: last_post.post_number,
        )
      end

      last_post = post.topic.posts.order(:post_number).last
      expect(last_post.raw).to eq("Another reply")
      expect(last_post.user_id).to eq(persona.user_id)
    end
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

    it "supports multiple function calls" do
      response1 = (<<~TXT).strip
          <function_calls>
          <invoke>
          <tool_name>search</tool_name>
          <tool_id>search</tool_id>
          <parameters>
          <search_query>testing various things</search_query>
          </parameters>
          </invoke>
          <invoke>
          <tool_name>search</tool_name>
          <tool_id>search</tool_id>
          <parameters>
          <search_query>another search</search_query>
          </parameters>
          </invoke>
          </function_calls>
       TXT

      response2 = "I found stuff"

      DiscourseAi::Completions::Llm.with_prepared_responses([response1, response2]) do
        playground.reply_to(third_post)
      end

      last_post = third_post.topic.reload.posts.order(:post_number).last

      expect(last_post.raw).to include("testing various things")
      expect(last_post.raw).to include("another search")
      expect(last_post.raw).to include("I found stuff")
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
        persona =
          AiPersona
            .find(
              DiscourseAi::AiBot::Personas::Persona.system_personas[
                DiscourseAi::AiBot::Personas::DallE3
              ],
            )
            .class_instance
            .new
        DiscourseAi::AiBot::Bot.as(bot_user, persona: persona)
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

  describe "#available_bot_usernames" do
    it "includes persona users" do
      persona = Fabricate(:ai_persona)
      persona.create_user!

      expect(playground.available_bot_usernames).to include(persona.user.username)
    end
  end

  describe "#conversation_context" do
    context "with limited context" do
      before do
        @old_persona = playground.bot.persona
        persona = Fabricate(:ai_persona, max_context_posts: 1)
        playground.bot.persona = persona.class_instance.new
      end

      after { playground.bot.persona = @old_persona }

      it "respects max_context_post" do
        context = playground.conversation_context(third_post)

        expect(context).to contain_exactly(
          *[{ type: :user, id: user.username, content: third_post.raw }],
        )
      end
    end

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

      # skips leading model reply which makes no sense cause first post was whisper
      expect(context).to contain_exactly(
        *[{ type: :user, id: user.username, content: third_post.raw }],
      )
    end

    context "with custom prompts" do
      it "When post custom prompt is present, we use that instead of the post content" do
        custom_prompt = [
          [
            { name: "time", arguments: { name: "time", timezone: "Buenos Aires" } }.to_json,
            "time",
            "tool_call",
          ],
          [
            { args: { timezone: "Buenos Aires" }, time: "2023-12-14 17:24:00 -0300" }.to_json,
            "time",
            "tool",
          ],
          ["I replied to the time command", bot_user.username],
        ]

        PostCustomPrompt.create!(post: second_post, custom_prompt: custom_prompt)

        context = playground.conversation_context(third_post)

        expect(context).to contain_exactly(
          *[
            { type: :user, id: user.username, content: first_post.raw },
            { type: :tool_call, content: custom_prompt.first.first, id: "time" },
            { type: :tool, id: "time", content: custom_prompt.second.first },
            { type: :model, content: custom_prompt.third.first },
            { type: :user, id: user.username, content: third_post.raw },
          ],
        )
      end
    end
  end
end
