# frozen_string_literal: true

return if !defined?(DiscourseAutomation)

describe DiscourseAi::Automation::LlmTriage do
  fab!(:category)
  fab!(:reply_user) { Fabricate(:user) }
  fab!(:personal_message) { Fabricate(:private_message_topic) }
  let(:canned_reply_text) { "Hello, this is a reply" }

  let(:automation) { Fabricate(:automation, script: "llm_triage", enabled: true) }

  fab!(:llm_model)

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
    SiteSetting.tagging_enabled = true
    add_automation_field("system_prompt", "hello %%POST%%")
    add_automation_field("search_for_text", "bad")
    add_automation_field("model", "custom:#{llm_model.id}")
    add_automation_field("category", category.id, type: "category")
    add_automation_field("tags", %w[aaa bbb], type: "tags")
    add_automation_field("hide_topic", true, type: "boolean")
    add_automation_field("flag_post", true, type: "boolean")
    add_automation_field("canned_reply", canned_reply_text)
    add_automation_field("canned_reply_user", reply_user.username, type: "user")
    add_automation_field("max_post_tokens", 100)
  end

  it "can trigger via automation" do
    post = Fabricate(:post, raw: "hello " * 5000)

    body = {
      model: "gpt-3.5-turbo-0301",
      usage: {
        prompt_tokens: 337,
        completion_tokens: 162,
        total_tokens: 499,
      },
      choices: [
        { message: { role: "assistant", content: "bad" }, finish_reason: "stop", index: 0 },
      ],
    }.to_json

    WebMock.stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
      status: 200,
      body: body,
    )

    automation.running_in_background!
    automation.trigger!({ "post" => post })

    topic = post.topic.reload
    expect(topic.category_id).to eq(category.id)
    expect(topic.tags.pluck(:name)).to contain_exactly("aaa", "bbb")
    expect(topic.visible).to eq(false)
    reply = topic.posts.order(:post_number).last
    expect(reply.raw).to eq(canned_reply_text)
    expect(reply.user.id).to eq(reply_user.id)

    ai_log = AiApiAuditLog.order("id desc").first
    expect(ai_log.feature_name).to eq("llm_triage")
    expect(ai_log.feature_context).to eq(
      { "automation_id" => automation.id, "automation_name" => automation.name },
    )

    count = ai_log.raw_request_payload.scan("hello").size
    # we could use the exact count here but it can get fragile
    # as we change tokenizers, this will give us reasonable confidence
    expect(count).to be <= (100)
    expect(count).to be > (50)
  end

  it "does not triage PMs by default" do
    post = Fabricate(:post, topic: personal_message)
    automation.running_in_background!
    automation.trigger!({ "post" => post })

    # nothing should happen, no classification, its a PM
  end

  it "will triage PMs if automation allows it" do
    # needs to be admin or it will not be able to just step in to
    # PM
    reply_user.update!(admin: true)
    add_automation_field("include_personal_messages", true, type: :boolean)
    post = Fabricate(:post, topic: personal_message)

    DiscourseAi::Completions::Llm.with_prepared_responses(["bad"]) do
      automation.running_in_background!
      automation.trigger!({ "post" => post })
    end

    last_post = post.topic.reload.posts.order(:post_number).last
    expect(last_post.raw).to eq(canned_reply_text)
  end

  it "does not reply to the canned_reply_user" do
    post = Fabricate(:post, user: reply_user)

    DiscourseAi::Completions::Llm.with_prepared_responses(["bad"]) do
      automation.running_in_background!
      automation.trigger!({ "post" => post })
    end

    last_post = post.topic.reload.posts.order(:post_number).last
    expect(last_post.raw).to eq post.raw
  end
end
