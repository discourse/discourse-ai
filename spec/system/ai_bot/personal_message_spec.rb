# frozen_string_literal: true

RSpec.describe "AI Bot - Personal Message", type: :system do
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }

  fab!(:user)
  fab!(:group)
  fab!(:gpt_4) { Fabricate(:llm_model, name: "gpt-4") }
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model("gpt-4") }

  let(:pm) do
    Fabricate(
      :private_message_topic,
      title: "AI Conversation Test",
      user: user,
      topic_allowed_users: [
        Fabricate.build(:topic_allowed_user, user: user),
        Fabricate.build(:topic_allowed_user, user: bot_user),
      ],
    )
  end

  let(:pm_posts) do
    posts = []
    i = 1
    3.times do
      posts << Fabricate(:post, topic: pm, user: user, raw: "test test test user reply #{i}")
      posts << Fabricate(:post, topic: pm, user: bot_user, raw: "test test test bot reply #{i}")
      i += 1
    end

    posts
  end

  before do
    SiteSetting.ai_enable_experimental_bot_ux = true

    SiteSetting.ai_bot_enabled = true
    toggle_enabled_bots(bots: [gpt_4])
    SiteSetting.ai_bot_allowed_groups = group.id.to_s
    sign_in(user)

    group.add(user)
    group.save

    allowed_persona = AiPersona.last
    allowed_persona.update!(allowed_group_ids: [group.id], enabled: true)

    sign_in(user)
  end

  it "has normal bot interaction when `ai_enable_experimental_bot_ux` is disabled" do
    SiteSetting.ai_enable_experimental_bot_ux = false
    visit "/"
    expect(page).to have_selector(".ai-bot-button")
    find(".ai-bot-button").click

    expect(composer).to be_opened
  end

  it "renders landing page when `ai_enable_experimental_bot_ux` is enabled" do
    visit "/"
    expect(page).to have_selector(".ai-bot-button")
    find(".ai-bot-button").click

    expect(page).to have_css(".custom-homepage__content-wrapper")
  end
end
