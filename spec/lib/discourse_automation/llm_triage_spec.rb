# frozen_string_literal: true

return if !defined?(DiscourseAutomation)

describe DiscourseAi::Automation::LlmTriage do
  fab!(:category)
  fab!(:reply_user) { Fabricate(:user) }

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
    add_automation_field("canned_reply", "Yo this is a reply")
    add_automation_field("canned_reply_user", reply_user.username, type: "user")
  end

  it "can trigger via automation" do
    post = Fabricate(:post)

    DiscourseAi::Completions::Llm.with_prepared_responses(["bad"]) do
      automation.running_in_background!
      automation.trigger!({ "post" => post })
    end

    topic = post.topic.reload
    expect(topic.category_id).to eq(category.id)
    expect(topic.tags.pluck(:name)).to contain_exactly("aaa", "bbb")
    expect(topic.visible).to eq(false)
    reply = topic.posts.order(:post_number).last
    expect(reply.raw).to eq("Yo this is a reply")
    expect(reply.user.id).to eq(reply_user.id)
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
