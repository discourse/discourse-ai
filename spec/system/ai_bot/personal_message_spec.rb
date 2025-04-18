# frozen_string_literal: true

RSpec.describe "AI Bot - Personal Message", type: :system do
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:ai_pm_homepage) { PageObjects::Components::AiPmHomepage.new }
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }
  let(:header_dropdown) { PageObjects::Components::NavigationMenu::HeaderDropdown.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

  fab!(:claude_2) do
    Fabricate(
      :llm_model,
      provider: "anthropic",
      url: "https://api.anthropic.com/v1/messages",
      name: "claude-2",
    )
  end
  fab!(:bot_user) do
    toggle_enabled_bots(bots: [claude_2])
    SiteSetting.ai_bot_enabled = true
    claude_2.reload.user
  end
  fab!(:bot) do
    persona =
      AiPersona
        .find(DiscourseAi::Personas::Persona.system_personas[DiscourseAi::Personas::General])
        .class_instance
        .new
    DiscourseAi::Personas::Bot.as(bot_user, persona: persona)
  end

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
  fab!(:topic_user) { Fabricate(:topic_user, topic: pm, user: user) }
  fab!(:topic_bot_user) { Fabricate(:topic_user, topic: pm, user: bot_user) }

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
    persona.update!(
      default_llm_id: claude_2.id,
      allow_chat_channel_mentions: true,
      allow_topic_mentions: true,
    )
    persona
  end

  before do
    SiteSetting.ai_enable_experimental_bot_ux = true
    SiteSetting.ai_bot_enabled = true
    Jobs.run_immediately!
    SiteSetting.ai_bot_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_0]}"
    sign_in(user)
  end

  it "has normal bot interaction when `ai_enable_experimental_bot_ux` is disabled" do
    SiteSetting.ai_enable_experimental_bot_ux = false
    visit "/"
    find(".ai-bot-button").click

    expect(ai_pm_homepage).to have_no_homepage
    expect(composer).to be_opened
  end

  context "when `ai_enable_experimental_bot_ux` is enabled" do
    it "renders landing page on bot click" do
      visit "/"
      find(".ai-bot-button").click
      expect(ai_pm_homepage).to have_homepage
      expect(sidebar).to be_visible
    end

    it "displays error when message is too short" do
      visit "/"
      find(".ai-bot-button").click

      ai_pm_homepage.input.fill_in(with: "a")
      ai_pm_homepage.submit
      expect(ai_pm_homepage).to have_too_short_dialog
      dialog.click_yes
      expect(composer).to be_closed
    end

    it "renders sidebar even when navigation menu is set to header" do
      SiteSetting.navigation_menu = "header dropdown"
      visit "/"
      find(".ai-bot-button").click
      expect(ai_pm_homepage).to have_homepage
      expect(sidebar).to be_visible
      expect(header_dropdown).to be_visible
    end

    it "hides default content in the sidebar" do
      visit "/"
      find(".ai-bot-button").click

      expect(ai_pm_homepage).to have_homepage
      expect(sidebar).to have_no_tags_section
      expect(sidebar).to have_no_section("categories")
      expect(sidebar).to have_no_section("messages")
      expect(sidebar).to have_no_section("chat-dms")
      expect(sidebar).to have_no_section("chat-channels")
      expect(sidebar).to have_no_section("user-threads")
    end

    it "shows the bot conversation in the sidebar" do
      visit "/"
      find(".ai-bot-button").click

      expect(ai_pm_homepage).to have_homepage
      expect(sidebar).to have_section("ai-conversations-history")
      expect(sidebar).to have_section_link(pm.title)
      expect(sidebar).to have_no_css("button.ai-new-question-button")
    end

    it "navigates to the bot conversation when clicked" do
      visit "/"
      find(".ai-bot-button").click

      expect(ai_pm_homepage).to have_homepage
      sidebar.find(
        ".sidebar-section[data-section-name='ai-conversations-history'] a.sidebar-section-link",
      ).click
      expect(topic_page).to have_topic_title(pm.title)
    end

    it "displays sidebar and 'new question' on the topic page" do
      topic_page.visit_topic(pm)
      expect(sidebar).to be_visible
      expect(sidebar).to have_css("button.ai-new-question-button")
    end

    it "redirect to the homepage when 'new question' is clicked" do
      topic_page.visit_topic(pm)
      expect(sidebar).to be_visible
      sidebar.find("button.ai-new-question-button").click
      expect(ai_pm_homepage).to have_homepage
    end

    it "can send a new message to the bot" do
      topic_page.visit_topic(pm)
      topic_page.click_reply_button
      expect(composer).to be_opened

      composer.fill_in(with: "Hello bot replying to you")
      composer.submit
      expect(page).to have_content("Hello bot replying to you")
    end
  end
end
