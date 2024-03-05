# frozen_string_literal: true

return if !defined?(DiscourseAutomation)

describe DiscourseAi::Automation::LlmTriage do
  fab!(:post)

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
    add_automation_field("flag_post", true, type: "boolean")
    add_automation_field("canned_reply", "Yo this is a reply")
    add_automation_field("canned_reply_user", user.username, type: "user")

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
    expect(reply.user.id).to eq(user.id)
  end
end
