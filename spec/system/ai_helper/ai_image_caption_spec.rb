# frozen_string_literal: true

RSpec.describe "AI image caption", type: :system, js: true do
  fab!(:user) { Fabricate(:admin, refresh_auto_groups: true) }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:popup) { PageObjects::Components::AiCaptionPopup.new }
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
end
