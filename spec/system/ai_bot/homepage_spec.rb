# frozen_string_literal: true

RSpec.describe "AI Bot - Homepage", type: :system do
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:ai_pm_homepage) { PageObjects::Components::AiPmHomepage.new }
  let(:header) { PageObjects::Pages::DiscourseAi::Header.new }
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }
  let(:header_dropdown) { PageObjects::Components::NavigationMenu::HeaderDropdown.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:user_2) { Fabricate(:user, refresh_auto_groups: true) }

  fab!(:claude_2) do
    Fabricate(
      :llm_model,
      provider: "anthropic",
      url: "https://api.anthropic.com/v1/messages",
      name: "claude-2",
      display_name: "Claude 2",
    )
  end
  fab!(:claude_2_dup) do
    Fabricate(
      :llm_model,
      provider: "anthropic",
      url: "https://api.anthropic.com/v1/messages",
      name: "claude-2",
      display_name: "Duplicate",
    )
  end
  fab!(:bot_user) do
    toggle_enabled_bots(bots: [claude_2, claude_2_dup])
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
      last_posted_at: Time.zone.now,
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
    pm.custom_fields[DiscourseAi::AiBot::TOPIC_AI_BOT_PM_FIELD] = "t"
    pm.save!

    SiteSetting.ai_bot_enable_dedicated_ux = true
    SiteSetting.ai_bot_enabled = true
    SiteSetting.navigation_menu = "sidebar"
    Jobs.run_immediately!
    SiteSetting.ai_bot_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_0]}"
    sign_in(user)
  end

  %w[enabled disabled].each do |value|
    before { SiteSetting.glimmer_post_stream_mode = value }

    context "when glimmer_post_stream_mode=#{value}" do
      context "when `ai_bot_enable_dedicated_ux` is enabled" do
        it "allows uploading files to a new conversation" do
          ai_pm_homepage.visit
          expect(ai_pm_homepage).to have_homepage

          file_path_1 = file_from_fixtures("logo.png", "images").path
          file_path_2 = file_from_fixtures("logo.jpg", "images").path

          attach_file([file_path_1, file_path_2]) do
            find(".ai-bot-upload-btn", visible: true).click
          end

          expect(page).to have_css(".ai-bot-upload", count: 2)

          ai_pm_homepage.input.fill_in(with: "Here are two image attachments")

          responses = ["hello user", "topic title"]
          DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
            ai_pm_homepage.submit
            expect(topic_page).to have_content("Here are two image attachments")
            expect(page).to have_css(".cooked img", count: 2)
          end

          find(".ai-new-question-button").click
          expect(ai_pm_homepage).to have_homepage
          expect(page).to have_no_css(".ai-bot-upload")
        end

        it "allows removing an upload before submission" do
          skip "TODO: fix this test for playwright"

          ai_pm_homepage.visit
          expect(ai_pm_homepage).to have_homepage

          file_path = file_from_fixtures("logo.png", "images").path
          attach_file([file_path]) { find(".ai-bot-upload-btn", visible: true).click }
          expect(page).to have_css(".ai-bot-upload", count: 1)

          # TODO: for some reason this line fails in playwright
          find(".ai-bot-upload__remove").click

          expect(page).to have_no_css(".ai-bot-upload")

          ai_pm_homepage.input.fill_in(with: "Message without attachments")

          responses = ["hello user", "topic title"]
          DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
            ai_pm_homepage.submit
            expect(topic_page).to have_content("Message without attachments")
            expect(page).to have_no_css(".cooked img")
          end
        end

        it "renders landing page on bot click" do
          visit "/"
          header.click_bot_button
          expect(ai_pm_homepage).to have_homepage
          expect(sidebar).to be_visible
        end

        it "displays error when message is too short" do
          visit "/"
          header.click_bot_button

          ai_pm_homepage.input.fill_in(with: "a")
          ai_pm_homepage.submit
          expect(ai_pm_homepage).to have_too_short_dialog
          dialog.click_yes
          expect(composer).to be_closed
        end

        it "hides default content in the sidebar" do
          visit "/"
          header.click_bot_button

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
          header.click_bot_button

          expect(ai_pm_homepage).to have_homepage
          expect(sidebar).to have_section("ai-conversations-history")
          expect(sidebar).to have_section_link("Today")
          expect(sidebar).to have_section_link(pm.title)
        end

        it "displays last_7_days label in the sidebar" do
          pm.update!(last_posted_at: Time.zone.now - 5.days)
          visit "/"
          header.click_bot_button

          expect(ai_pm_homepage).to have_homepage
          expect(sidebar).to have_section_link("Last 7 days")
        end

        it "displays last_30_days label in the sidebar" do
          pm.update!(last_posted_at: Time.zone.now - 28.days)
          visit "/"
          header.click_bot_button

          expect(ai_pm_homepage).to have_homepage
          expect(sidebar).to have_section_link("Last 30 days")
        end

        it "displays month and year label in the sidebar for older conversations" do
          pm.update!(last_posted_at: "2024-04-10 15:39:11.406192000 +00:00")
          visit "/"
          header.click_bot_button

          expect(ai_pm_homepage).to have_homepage
          expect(sidebar).to have_section_link("Apr 2024")
        end

        it "navigates to the bot conversation when clicked" do
          visit "/"
          header.click_bot_button

          expect(ai_pm_homepage).to have_homepage
          ai_pm_homepage.click_fist_sidebar_conversation
          expect(topic_page).to have_topic_title(pm.title)
        end

        it "displays the shuffle icon when on homepage or bot PM" do
          visit "/"
          expect(header).to have_icon_in_bot_button(icon: "robot")
          header.click_bot_button

          expect(header).to have_icon_in_bot_button(icon: "shuffle")

          # Go to a PM and assert that the icon is still shuffle
          ai_pm_homepage.click_fist_sidebar_conversation
          expect(header).to have_icon_in_bot_button(icon: "shuffle")

          # Go back home and assert that the icon is now robot again
          header.click_bot_button
          expect(header).to have_icon_in_bot_button(icon: "robot")
        end

        it "displays 'new question' button on homepage and topic page" do
          topic_page.visit_topic(pm)
          expect(ai_pm_homepage).to have_new_question_button

          ai_pm_homepage.visit
          expect(ai_pm_homepage).to have_new_question_button
        end

        it "redirect to the homepage when 'new question' is clicked" do
          topic_page.visit_topic(pm)
          expect(sidebar).to be_visible
          ai_pm_homepage.click_new_question_button
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

        it "does not render custom sidebar on non-authored bot pms" do
          # Include user_2 in the PM by creating a new post and topic_allowed_user association
          Fabricate(:post, topic: pm, user: user_2, post_number: 4)
          Fabricate(:topic_allowed_user, topic: pm, user: user_2)
          sign_in(user_2)

          topic_page.visit_topic(pm)

          expect(sidebar).to be_visible
          expect(sidebar).to have_no_section("ai-conversations-history")
          expect(sidebar).to have_no_css("button.ai-new-question-button")
        end

        it "does not include non-authored bot pms in sidebar" do
          # Include user_2 in the PM by creating a new post and topic_allowed_user association
          Fabricate(:post, topic: pm, user: user_2, post_number: 4)
          Fabricate(:topic_allowed_user, topic: pm, user: user_2)
          sign_in(user_2)
          visit "/"
          header.click_bot_button
          expect(ai_pm_homepage).to have_homepage
          expect(sidebar).to have_no_section_link(pm.title)
        end

        it "renders empty state in sidebar with no bot PM history" do
          sign_in(user_2)
          ai_pm_homepage.visit
          expect(ai_pm_homepage).to have_empty_state
        end

        it "Allows choosing persona and LLM" do
          ai_pm_homepage.visit

          ai_pm_homepage.llm_selector.expand
          ai_pm_homepage.llm_selector.select_row_by_name(claude_2_dup.display_name)
          ai_pm_homepage.llm_selector.collapse

          # confirm memory works for llm selection
          ai_pm_homepage.visit
          expect(ai_pm_homepage.llm_selector).to have_selected_name(claude_2_dup.display_name)
        end

        it "does not render back to forum link" do
          ai_pm_homepage.visit
          expect(ai_pm_homepage).to have_no_sidebar_back_link
        end

        context "with hamburger menu" do
          before { SiteSetting.navigation_menu = "header dropdown" }
          it "keeps robot icon in the header and doesn't display sidebar back link" do
            visit "/"
            expect(header).to have_icon_in_bot_button(icon: "robot")
            header.click_bot_button
            expect(ai_pm_homepage).to have_homepage
            expect(header).to have_icon_in_bot_button(icon: "robot")
            expect(ai_pm_homepage).to have_no_sidebar_back_link
          end

          it "still renders the sidebar" do
            visit "/"
            header.click_bot_button
            expect(ai_pm_homepage).to have_homepage
            expect(sidebar).to be_visible
            expect(header_dropdown).to be_visible
          end
        end
      end

      context "when `ai_bot_enable_dedicated_ux` is disabled" do
        before { SiteSetting.ai_bot_enable_dedicated_ux = false }

        it "opens composer on bot click" do
          visit "/"
          header.click_bot_button

          expect(ai_pm_homepage).to have_no_homepage
          expect(composer).to be_opened
        end

        it "does not render sidebar when navigation menu is set to header on pm" do
          SiteSetting.navigation_menu = "header dropdown"
          topic_page.visit_topic(pm)

          expect(ai_pm_homepage).to have_no_homepage
          expect(sidebar).to be_not_visible
          expect(header_dropdown).to be_visible
        end

        it "shows default content in the sidebar" do
          topic_page.visit_topic(pm)

          expect(sidebar).to have_section("categories")
          expect(sidebar).to have_section("messages")
          expect(sidebar).to have_section("chat-dms")
          expect(sidebar).to have_no_css("button.ai-new-question-button")
        end
      end

      context "with header dropdown on mobile", mobile: true do
        before { SiteSetting.navigation_menu = "header dropdown" }

        it "displays the new question button in the menu when viewing a PM" do
          ai_pm_homepage.visit
          header_dropdown.open
          expect(ai_pm_homepage).to have_new_question_button

          topic_page.visit_topic(pm)
          header_dropdown.open
          ai_pm_homepage.click_new_question_button

          # Hamburger sidebar is closed
          expect(header_dropdown).to have_no_dropdown_visible
        end
      end
    end
  end
end
