# frozen_string_literal: true

RSpec.describe "AI image caption", type: :system, js: true do
  fab!(:user) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:non_member_group) { Fabricate(:group) }
  let(:user_preferences_ai_page) { PageObjects::Pages::UserPreferencesAi.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:popup) { PageObjects::Components::AiCaptionPopup.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:file_path) { file_from_fixtures("logo.jpg", "images").path }
  let(:caption) do
    "The image shows a stylized speech bubble icon with a multicolored border on a black background."
  end
  let(:caption_with_attrs) do
    "#{caption} (#{I18n.t("discourse_ai.ai_helper.image_caption.attribution")})"
  end

  before do
    Group.find_by(id: Group::AUTO_GROUPS[:admins]).add(user)
    SiteSetting.ai_helper_model = "fake:fake"
    SiteSetting.ai_llava_endpoint = "https://example.com"
    SiteSetting.ai_helper_enabled_features = "image_caption"
    sign_in(user)

    stub_request(:post, "https://example.com/predictions").to_return(
      status: 200,
      body: { output: caption.gsub(" ", " |").split("|") }.to_json,
    )
  end

  shared_examples "shows no image caption button" do
    it "should not show an image caption button" do
      visit("/latest")
      page.find("#create-topic").click
      attach_file([file_path]) { composer.click_toolbar_button("upload") }
      wait_for { composer.has_no_in_progress_uploads? }
      expect(popup).to have_no_generate_caption_button
    end
  end

  context "when not a member of ai helper group" do
    before { SiteSetting.ai_helper_allowed_groups = non_member_group.id.to_s }
    include_examples "shows no image caption button"
  end

  context "when image caption feature is disabled" do
    before { SiteSetting.ai_helper_enabled_features = "" }
    include_examples "shows no image caption button"
  end

  context "when triggering caption with AI on desktop" do
    it "should show an image caption in an input field" do
      visit("/latest")
      page.find("#create-topic").click
      attach_file([file_path]) { composer.click_toolbar_button("upload") }
      popup.click_generate_caption
      expect(popup.has_caption_popup_value?(caption_with_attrs)).to eq(true)
      popup.save_caption
      wait_for { page.find(".image-wrapper img")["alt"] == caption_with_attrs }
      expect(page.find(".image-wrapper img")["alt"]).to eq(caption_with_attrs)
    end

    it "should allow you to cancel a caption request" do
      visit("/latest")
      page.find("#create-topic").click
      attach_file([file_path]) { composer.click_toolbar_button("upload") }
      popup.click_generate_caption
      popup.cancel_caption
      expect(popup).to have_no_disabled_generate_button
    end
  end

  context "when triggering caption with AI on mobile", mobile: true do
    it "should show update the image alt text with the caption" do
      visit("/latest")
      page.find("#create-topic").click
      attach_file([file_path]) { page.find(".mobile-file-upload").click }
      page.find(".mobile-preview").click
      popup.click_generate_caption
      wait_for { page.find(".image-wrapper img")["alt"] == caption_with_attrs }
      expect(page.find(".image-wrapper img")["alt"]).to eq(caption_with_attrs)
    end
  end

  describe "automatic image captioning" do
    context "when toggling the setting from the user preferences page" do
      before { user.user_option.update!(auto_image_caption: false) }

      it "should update the preference to enabled" do
        user_preferences_ai_page.visit(user)
        user_preferences_ai_page.toggle_setting("pref-auto-image-caption")
        user_preferences_ai_page.save_changes
        wait_for(timeout: 5) { user.reload.user_option.auto_image_caption }
        expect(user.reload.user_option.auto_image_caption).to eq(true)
      end
    end

    context "when the user preference is disabled" do
      before { user.user_option.update!(auto_image_caption: false) }

      it "should show a prompt when submitting a post with captionable images uploaded" do
        visit("/latest")
        page.find("#create-topic").click
        attach_file([file_path]) { composer.click_toolbar_button("upload") }
        wait_for { composer.has_no_in_progress_uploads? }
        composer.fill_title("I love using Discourse! It is my favorite forum software")
        composer.create
        expect(dialog).to be_open
      end

      it "should not show a prompt when submitting a post with no captionable images uploaded" do
        original_file_path = Rails.root.join("spec/fixtures/images/logo.jpg")
        temp_file_path = Rails.root.join("spec/fixtures/images/An image of Discourse logo.jpg")
        FileUtils.cp(original_file_path, temp_file_path)
        visit("/latest")
        page.find("#create-topic").click
        attach_file([temp_file_path]) { composer.click_toolbar_button("upload") }
        wait_for { composer.has_no_in_progress_uploads? }
        composer.fill_title("I love using Discourse! It is my favorite forum software")
        composer.create
        expect(dialog).to be_closed
      end

      it "should auto caption the existing images and update the preference when dialog is accepted" do
        visit("/latest")
        page.find("#create-topic").click
        attach_file([file_path]) { composer.click_toolbar_button("upload") }
        wait_for { composer.has_no_in_progress_uploads? }
        composer.fill_title("I love using Discourse! It is my favorite forum software")
        composer.create
        dialog.click_yes
        wait_for(timeout: 100) { page.find("#post_1 .cooked img")["alt"] == caption_with_attrs }
        expect(page.find("#post_1 .cooked img")["alt"]).to eq(caption_with_attrs)
      end
    end

    context "when the user preference is enabled" do
      before { user.user_option.update!(auto_image_caption: true) }

      skip "TODO: Fix auto_image_caption user option not present in testing environment?" do
        it "should auto caption the image after uploading" do
          visit("/latest")
          page.find("#create-topic").click
          attach_file([Rails.root.join("spec/fixtures/images/logo.jpg")]) do
            composer.click_toolbar_button("upload")
          end
          wait_for { composer.has_no_in_progress_uploads? }
          wait_for { page.find(".image-wrapper img")["alt"] == caption_with_attrs }
          expect(page.find(".image-wrapper img")["alt"]).to eq(caption_with_attrs)
        end
      end
    end
  end
end
