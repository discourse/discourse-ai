# frozen_string_literal: true

return if !defined?(DiscourseAutomation)

describe DiscourseAi::Automation::LlmPersonaTriage do
  fab!(:user)
  fab!(:bot_user) { Fabricate(:user) }

  fab!(:llm_model) do
    Fabricate(:llm_model, provider: "anthropic", name: "claude-3-opus", enabled_chat_bot: true)
  end

  fab!(:ai_persona) do
    persona =
      Fabricate(
        :ai_persona,
        name: "Triage Helper",
        description: "A persona that helps with triaging posts",
        system_prompt: "You are a helpful assistant that triages posts",
        default_llm: llm_model,
      )

    # Create the user for this persona
    persona.update!(user_id: bot_user.id)
    persona
  end

  let(:automation) { Fabricate(:automation, script: "llm_persona_triage", enabled: true) }

  def add_automation_field(name, value, type: "text")
    automation.fields.create!(
      component: type,
      name: name,
      metadata: {
        value: value,
      },
      target: "script",
    )
  end

  before do
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_0]}"

    add_automation_field("persona", ai_persona.id, type: "choices")
    add_automation_field("whisper", false, type: "boolean")
  end

  it "can respond to a post using the specified persona" do
    post = Fabricate(:post, raw: "This is a test post that needs triage")

    response_text = "I've analyzed your post and can help with that."

    DiscourseAi::Completions::Llm.with_prepared_responses([response_text]) do
      automation.running_in_background!
      automation.trigger!({ "post" => post })
    end

    topic = post.topic.reload
    last_post = topic.posts.order(:post_number).last

    expect(topic.posts.count).to eq(2)

    # Verify that the response was posted by the persona's user
    expect(last_post.user_id).to eq(bot_user.id)
    expect(last_post.raw).to eq(response_text)
    expect(last_post.post_type).to eq(Post.types[:regular]) # Not a whisper
  end

  it "can respond with a whisper when configured to do so" do
    add_automation_field("whisper", true, type: "boolean")
    post = Fabricate(:post, raw: "This is another test post for triage")

    response_text = "Staff-only response to your post."

    DiscourseAi::Completions::Llm.with_prepared_responses([response_text]) do
      automation.running_in_background!
      automation.trigger!({ "post" => post })
    end

    topic = post.topic.reload
    last_post = topic.posts.order(:post_number).last

    # Verify that the response is a whisper
    expect(last_post.user_id).to eq(bot_user.id)
    expect(last_post.raw).to eq(response_text)
    expect(last_post.post_type).to eq(Post.types[:whisper]) # This should be a whisper
  end

  it "does not respond to posts made by bots" do
    bot = Fabricate(:bot)
    bot_post = Fabricate(:post, user: bot, raw: "This is a bot post")

    # The automation should not trigger for bot posts
    DiscourseAi::Completions::Llm.with_prepared_responses(["Response"]) do
      automation.running_in_background!
      automation.trigger!({ "post" => bot_post })
    end

    # Verify no new post was created
    expect(bot_post.topic.reload.posts.count).to eq(1)
  end

  it "handles errors gracefully" do
    post = Fabricate(:post, raw: "Error-triggering post")

    # Set up to cause an error
    ai_persona.update!(user_id: nil)

    # Should not raise an error
    expect {
      automation.running_in_background!
      automation.trigger!({ "post" => post })
    }.not_to raise_error

    # Verify no new post was created
    expect(post.topic.reload.posts.count).to eq(1)
  end

  it "passes topic metadata in context when responding to topic" do
    # Create a category and tags for the test
    category = Fabricate(:category, name: "Test Category")
    tag1 = Fabricate(:tag, name: "test-tag")
    tag2 = Fabricate(:tag, name: "support")

    # Create a topic with category and tags
    topic =
      Fabricate(
        :topic,
        title: "Important Question About Feature",
        category: category,
        tags: [tag1, tag2],
        user: user,
      )

    # Create a post in that topic
    _post =
      Fabricate(
        :post,
        topic: topic,
        user: user,
        raw: "This is a test post in a categorized and tagged topic",
      )

    post2 =
      Fabricate(:post, topic: topic, user: user, raw: "This is another post in the same topic")

    # Capture the prompt sent to the LLM to verify it contains metadata
    prompt = nil

    DiscourseAi::Completions::Llm.with_prepared_responses(
      ["I've analyzed your question"],
    ) do |_, _, _prompts|
      automation.running_in_background!
      automation.trigger!({ "post" => post2 })
      prompt = _prompts.first
    end

    context = prompt.messages[1][:content] # The second message should be the triage prompt

    # Verify that topic metadata is included in the context
    expect(context).to include("Important Question About Feature")
    expect(context).to include("Test Category")
    expect(context).to include("test-tag")
    expect(context).to include("support")
  end

  it "interacts correctly with PMs" do
    # Create a private message topic
    pm_topic = Fabricate(:private_message_topic, user: user, title: "Important PM")

    # Create initial PM post
    pm_post =
      Fabricate(
        :post,
        topic: pm_topic,
        user: user,
        raw: "This is a private message that needs triage",
      )

    # Create a follow-up post
    pm_post2 =
      Fabricate(
        :post,
        topic: pm_topic,
        user: user,
        raw: "Adding more context to my private message",
      )

    # Capture the prompt sent to the LLM
    prompt = nil

    original_user_ids = pm_topic.topic_allowed_users.pluck(:user_id)

    DiscourseAi::Completions::Llm.with_prepared_responses(
      ["I've received your private message"],
    ) do |_, _, _prompts|
      automation.running_in_background!
      automation.trigger!({ "post" => pm_post2 })
      prompt = _prompts.first
    end

    context = prompt.messages[1][:content]

    # Verify that PM metadata is included in the context
    expect(context).to include("Important PM")
    expect(context).to include(pm_post.raw)
    expect(context).to include(pm_post2.raw)

    reply = pm_topic.posts.order(:post_number).last
    expect(reply.raw).to eq("I've received your private message")

    topic = reply.topic

    # should not inject persona into allowed users
    expect(topic.topic_allowed_users.pluck(:user_id).sort).to eq(original_user_ids.sort)
  end
end
