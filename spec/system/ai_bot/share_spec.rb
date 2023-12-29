# frozen_string_literal: true
RSpec.describe "Share conversation", type: :system do
  fab!(:admin) { Fabricate(:admin, username: "ai_sharer") }
  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT4_ID) }

  let(:pm) do
    Fabricate(
      :private_message_topic,
      title: "This is my special PM",
      user: admin,
      topic_allowed_users: [
        Fabricate.build(:topic_allowed_user, user: admin),
        Fabricate.build(:topic_allowed_user, user: bot_user),
      ],
    )
  end

  let(:pm_posts) do
    posts = []
    i = 1
    3.times do
      posts << Fabricate(:post, topic: pm, user: admin, raw: "test test test user reply #{i}")
      posts << Fabricate(:post, topic: pm, user: bot_user, raw: "test test test bot reply #{i}")
      i += 1
    end

    posts
  end

  before do
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_enabled_chat_bots = "gpt-4"
    sign_in(admin)

    bot_user.update!(username: "gpt-4")

    Group.refresh_automatic_groups!
    pm
    pm_posts
  end

  it "can share a conversation" do
    visit(pm.url)

    # clipboard functionality is extremely hard to test
    # we would need special permissions in chrome driver to enable full access
    # instead we use a secret variable to signal that we want to store clipboard
    # data in window.discourseAiClipboard
    page.execute_script("window.discourseAiTestClipboard = true")

    find("#post_2 .post-action-menu__share").click

    try_until_success do
      clip_text = page.evaluate_script("window.discourseAiClipboard")
      expect(clip_text).to be_present
    end

    conversation = (<<~TEXT).strip
      <details class='ai-quote'>
      <summary>
      <span>This is my special PM</span>
      <span title='Conversation with AI'>AI</span>
      </summary>

      **ai_sharer:**

      test test test user reply 1

      **gpt-4:**

      test test test bot reply 1
      </details>
    TEXT

    expect(conversation).to eq(clip_text)

    # Test modal functionality as well
    page.evaluate_script("window.discourseAiClipboard = null")

    find("#post_6 .post-action-menu__share").click
    find(".ai-share-modal__slider input").set("2")
    find(".ai-share-modal button.btn-primary").click

    try_until_success do
      clip_text = page.evaluate_script("window.discourseAiClipboard")
      expect(clip_text).to be_present
    end

    conversation = (<<~TEXT).strip
      <details class='ai-quote'>
      <summary>
      <span>This is my special PM</span>
      <span title='Conversation with AI'>AI</span>
      </summary>

      **ai_sharer:**

      test test test user reply 2

      **gpt-4:**

      test test test bot reply 2

      **ai_sharer:**

      test test test user reply 3

      **gpt-4:**

      test test test bot reply 3
      </details>
    TEXT

    expect(conversation).to eq(clip_text)
  end
end
