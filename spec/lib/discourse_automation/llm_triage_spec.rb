# frozen_string_literal: true

return if !defined?(DiscourseAutomation)

describe DiscourseAutomation::LlmTriage do
  fab!(:post) { Fabricate(:post) }

  def triage(**args)
    DiscourseAutomation::LlmTriage.handle(**args)
  end

  it "does nothing if it does not pass triage" do
    stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
      status: 200,
      body: { choices: [{ message: { content: "good" } }] }.to_json,
    )

    triage(
      post: post,
      model: "gpt-4",
      hide_topic: true,
      system_prompt: "test %%POST%%",
      search_for_text: "bad",
    )

    expect(post.topic.reload.visible).to eq(true)
  end

  it "can hide topics on triage with claude" do
    stub_request(:post, "https://api.anthropic.com/v1/complete").to_return(
      status: 200,
      body: { completion: "bad" }.to_json,
    )

    triage(
      post: post,
      model: "claude-2",
      hide_topic: true,
      system_prompt: "test %%POST%%",
      search_for_text: "bad",
    )

    expect(post.topic.reload.visible).to eq(false)
  end

  it "can hide topics on triage with claude" do
    stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
      status: 200,
      body: { choices: [{ message: { content: "bad" } }] }.to_json,
    )

    triage(
      post: post,
      model: "gpt-4",
      hide_topic: true,
      system_prompt: "test %%POST%%",
      search_for_text: "bad",
    )

    expect(post.topic.reload.visible).to eq(false)
  end

  it "can categorize topics on triage" do
    category = Fabricate(:category)

    stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
      status: 200,
      body: { choices: [{ message: { content: "bad" } }] }.to_json,
    )

    triage(
      post: post,
      model: "gpt-4",
      category_id: category.id,
      system_prompt: "test %%POST%%",
      search_for_text: "bad",
    )

    expect(post.topic.reload.category_id).to eq(category.id)
  end

  it "can reply to topics on triage" do
    user = Fabricate(:user)

    stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
      status: 200,
      body: { choices: [{ message: { content: "bad" } }] }.to_json,
    )

    triage(
      post: post,
      model: "gpt-4",
      system_prompt: "test %%POST%%",
      search_for_text: "bad",
      canned_reply: "test canned reply 123",
      canned_reply_user: user.username,
    )

    reply = post.topic.posts.order(:post_number).last

    expect(reply.raw).to eq("test canned reply 123")
    expect(reply.user.id).to eq(user.id)
  end

  let(:automation) { Fabricate(:automation, script: "llm_triage", enabled: true) }

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

  it "can trigger via automation" do
    SiteSetting.tagging_enabled = true

    category = Fabricate(:category)
    user = Fabricate(:user)

    add_automation_field("system_prompt", "hello %%POST%%")
    add_automation_field("search_for_text", "bad")
    add_automation_field("model", "gpt-4")
    add_automation_field("category", category.id, type: "category")
    add_automation_field("tags", %w[aaa bbb], type: "tags")
    add_automation_field("hide_topic", true, type: "boolean")
    add_automation_field("canned_reply", "Yo this is a reply")
    add_automation_field("canned_reply_user", user.username, type: "user")

    stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
      status: 200,
      body: { choices: [{ message: { content: "bad" } }] }.to_json,
    )

    automation.running_in_background!
    automation.trigger!({ "post" => post })

    topic = post.topic.reload
    expect(topic.category_id).to eq(category.id)
    expect(topic.tags.pluck(:name)).to contain_exactly("aaa", "bbb")
    expect(topic.visible).to eq(false)
    reply = topic.posts.order(:post_number).last
    expect(reply.raw).to eq("Yo this is a reply")
    expect(reply.user.id).to eq(user.id)
  end
end
