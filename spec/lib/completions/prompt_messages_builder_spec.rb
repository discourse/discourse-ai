# frozen_string_literal: true

describe DiscourseAi::Completions::PromptMessagesBuilder do
  let(:builder) { DiscourseAi::Completions::PromptMessagesBuilder.new }
  fab!(:user)
  fab!(:bot_user) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }

  it "should allow merging user messages" do
    builder.push(type: :user, content: "Hello", name: "Alice")
    builder.push(type: :user, content: "World", name: "Bob")

    expect(builder.to_a).to eq([{ type: :user, content: "Alice: Hello\nBob: World" }])
  end

  it "should allow adding uploads" do
    builder.push(type: :user, content: "Hello", name: "Alice", upload_ids: [1, 2])

    expect(builder.to_a).to eq(
      [{ type: :user, content: ["Hello", { upload_id: 1 }, { upload_id: 2 }], name: "Alice" }],
    )
  end

  it "should support function calls" do
    builder.push(type: :user, content: "Echo 123 please", name: "Alice")
    builder.push(type: :tool_call, content: "echo(123)", name: "echo", id: 1)
    builder.push(type: :tool, content: "123", name: "echo", id: 1)
    builder.push(type: :user, content: "Hello", name: "Alice")
    expected = [
      { type: :user, content: "Echo 123 please", name: "Alice" },
      { type: :tool_call, content: "echo(123)", name: "echo", id: "1" },
      { type: :tool, content: "123", name: "echo", id: "1" },
      { type: :user, content: "Hello", name: "Alice" },
    ]
    expect(builder.to_a).to eq(expected)
  end

  it "should drop a tool call if it is not followed by tool" do
    builder.push(type: :user, content: "Echo 123 please", name: "Alice")
    builder.push(type: :tool_call, content: "echo(123)", name: "echo", id: 1)
    builder.push(type: :user, content: "OK", name: "James")

    expected = [{ type: :user, content: "Alice: Echo 123 please\nJames: OK" }]
    expect(builder.to_a).to eq(expected)
  end

  it "should format messages for topic style" do
    # Create a topic with tags
    topic = Fabricate(:topic, title: "This is an Example Topic")

    # Add tags to the topic
    topic.tags = [Fabricate(:tag, name: "tag1"), Fabricate(:tag, name: "tag2")]
    topic.save!

    builder.topic = topic
    builder.push(type: :user, content: "I like frogs", name: "Bob")
    builder.push(type: :user, content: "How do I solve this?", name: "Alice")

    result = builder.to_a(style: :topic)

    content = result[0][:content]

    expect(content).to include("This is an Example Topic")
    expect(content).to include("tag1")
    expect(content).to include("tag2")
    expect(content).to include("Bob: I like frogs")
    expect(content).to include("Alice")
    expect(content).to include("How do I solve this")
  end

  describe ".messages_from_chat" do
    fab!(:dm_channel) { Fabricate(:direct_message_channel, users: [user, bot_user]) }
    fab!(:dm_message1) do
      Fabricate(:chat_message, chat_channel: dm_channel, user: user, message: "Hello bot")
    end
    fab!(:dm_message2) do
      Fabricate(:chat_message, chat_channel: dm_channel, user: bot_user, message: "Hello human")
    end
    fab!(:dm_message3) do
      Fabricate(:chat_message, chat_channel: dm_channel, user: user, message: "How are you?")
    end

    fab!(:public_channel) { Fabricate(:category_channel) }
    fab!(:public_message1) do
      Fabricate(:chat_message, chat_channel: public_channel, user: user, message: "Hello everyone")
    end
    fab!(:public_message2) do
      Fabricate(:chat_message, chat_channel: public_channel, user: bot_user, message: "Hi there")
    end

    fab!(:thread_original) do
      Fabricate(:chat_message, chat_channel: public_channel, user: user, message: "Thread starter")
    end
    fab!(:thread) do
      Fabricate(:chat_thread, channel: public_channel, original_message: thread_original)
    end
    fab!(:thread_reply1) do
      Fabricate(
        :chat_message,
        chat_channel: public_channel,
        user: other_user,
        message: "Thread reply",
        thread: thread,
      )
    end

    fab!(:upload) { Fabricate(:upload, user: user) }
    fab!(:message_with_upload) do
      Fabricate(
        :chat_message,
        chat_channel: dm_channel,
        user: user,
        message: "Check this image",
        upload_ids: [upload.id],
      )
    end

    it "processes messages from direct message channels" do
      context =
        described_class.messages_from_chat(
          dm_message3,
          channel: dm_channel,
          context_post_ids: nil,
          max_messages: 10,
          include_uploads: false,
          bot_user_ids: [bot_user.id],
          instruction_message: nil,
        )

      # this is all we got cause it is assuming threading
      expect(context).to eq([{ type: :user, content: "How are you?", name: user.username }])
    end

    it "includes uploads when include_uploads is true" do
      message_with_upload.reload
      expect(message_with_upload.uploads).to include(upload)

      context =
        described_class.messages_from_chat(
          message_with_upload,
          channel: dm_channel,
          context_post_ids: nil,
          max_messages: 10,
          include_uploads: true,
          bot_user_ids: [bot_user.id],
          instruction_message: nil,
        )

      # Find the message with upload
      message = context.find { |m| m[:content] == ["Check this image", { upload_id: upload.id }] }
      expect(message).to be_present
    end

    it "doesn't include uploads when include_uploads is false" do
      # Make sure the upload is associated with the message
      message_with_upload.reload
      expect(message_with_upload.uploads).to include(upload)

      context =
        described_class.messages_from_chat(
          message_with_upload,
          channel: dm_channel,
          context_post_ids: nil,
          max_messages: 10,
          include_uploads: false,
          bot_user_ids: [bot_user.id],
          instruction_message: nil,
        )

      # Find the message with upload
      message = context.find { |m| m[:content] == "Check this image" }
      expect(message).to be_present
      expect(message[:upload_ids]).to be_nil
    end

    it "properly handles uploads in public channels with multiple users" do
      _first_message =
        Fabricate(:chat_message, chat_channel: public_channel, user: user, message: "First message")

      _message_with_upload =
        Fabricate(
          :chat_message,
          chat_channel: public_channel,
          user: other_user,
          message: "Message with image",
          upload_ids: [upload.id],
        )

      last_message =
        Fabricate(:chat_message, chat_channel: public_channel, user: user, message: "Final message")

      context =
        described_class.messages_from_chat(
          last_message,
          channel: public_channel,
          context_post_ids: nil,
          max_messages: 3,
          include_uploads: true,
          bot_user_ids: [bot_user.id],
          instruction_message: nil,
        )

      expect(context.length).to eq(1)
      content = context.first[:content]

      expect(content.length).to eq(3)
      expect(content[0]).to include("First message")
      expect(content[0]).to include("Message with image")
      expect(content[1]).to include({ upload_id: upload.id })
      expect(content[2]).to include("Final message")
    end
  end

  describe ".messages_from_post" do
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

    context "with limited context" do
      it "respects max_context_posts" do
        context =
          described_class.messages_from_post(
            third_post,
            max_posts: 1,
            bot_usernames: [bot_user.username],
            include_uploads: false,
          )

        expect(context).to contain_exactly(
          *[{ type: :user, id: user.username, content: third_post.raw }],
        )
      end
    end

    it "includes previous posts ordered by post_number" do
      context =
        described_class.messages_from_post(
          third_post,
          max_posts: 10,
          bot_usernames: [bot_user.username],
          include_uploads: false,
        )

      expect(context).to eq(
        [
          { type: :user, content: "This is a reply by the user", id: user.username },
          { type: :model, content: "This is a bot reply" },
          { type: :user, content: "This is a second reply by the user", id: user.username },
        ],
      )
    end

    it "only include regular posts" do
      first_post.update!(post_type: Post.types[:whisper])

      context =
        described_class.messages_from_post(
          third_post,
          max_posts: 10,
          bot_usernames: [bot_user.username],
          include_uploads: false,
        )

      # skips leading model reply which makes no sense cause first post was whisper
      expect(context).to eq(
        [{ type: :user, content: "This is a second reply by the user", id: user.username }],
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

        context =
          described_class.messages_from_post(
            third_post,
            max_posts: 10,
            bot_usernames: [bot_user.username],
            include_uploads: false,
          )

        expect(context).to eq(
          [
            { type: :user, content: "This is a reply by the user", id: user.username },
            { type: :tool_call, content: custom_prompt.first.first, id: "time" },
            { type: :tool, id: "time", content: custom_prompt.second.first },
            { type: :model, content: custom_prompt.third.first },
            { type: :user, content: "This is a second reply by the user", id: user.username },
          ],
        )
      end
    end
  end
end
