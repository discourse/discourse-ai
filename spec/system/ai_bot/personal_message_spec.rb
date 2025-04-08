# frozen_string_literal: true

RSpec.describe "AI Bot - Personal Message", type: :system do
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:ai_pm_homepage) { PageObjects::Components::AiPmHomepage.new }
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }
  let(:header_dropdown) { PageObjects::Components::NavigationMenu::HeaderDropdown.new }

  fab!(:user)
  fab!(:group)

  fab!(:bot_user) do
    user = Fabricate(:user)
    AiPersona.last.update!(user_id: user.id)
    user
  end
  fab!(:llm_model) { Fabricate(:llm_model, enabled_chat_bot: true) }

  fab!(:pm) { Fabricate(:private_message_topic, title: "AI Conversation Test", user: user) }
  fab!(:reply) do
    Fabricate(:post, topic: pm, user: user, post_number: 1, raw: "test test test user reply")
  end
  fab!(:bot_reply) do
    Fabricate(:post, topic: pm, user: bot_user, post_number: 2, raw: "test test test bot reply")
  end
  fab!(:topic_user) { Fabricate(:topic_user, topic: pm, user: user) }
  fab!(:topic_bot_user) { Fabricate(:topic_user, topic: pm, user: bot_user) }

  before do
    SiteSetting.ai_enable_experimental_bot_ux = true
    SiteSetting.ai_bot_enabled = true
    toggle_enabled_bots(bots: [llm_model])
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

    it "renders sidebar even when navigation menu is set to header" do
      SiteSetting.navigation_menu = "header dropdown"
      visit "/"
      find(".ai-bot-button").click
      expect(ai_pm_homepage).to have_homepage
      expect(sidebar).to be_visible
      epxect(header_dropdown).to be_visible
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
      expect(sidebar).to have_section("custom-messages")
      expect(sidebar).to have_section_link(pm.title, href: pm.relative_url)
    end
  end
end
