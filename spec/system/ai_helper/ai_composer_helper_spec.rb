# frozen_string_literal: true

RSpec.describe "AI Composer helper", type: :system, js: true do
  fab!(:user) { Fabricate(:user) }

  before do
    SiteSetting.composer_ai_helper_enabled = true
    sign_in(user)
  end

  let(:composer) { PageObjects::Components::Composer.new }
  let(:ai_helper_modal) { PageObjects::Modals::AIHelper.new }

  context "When using the helper without selecting text" do
    it "replaces the composed message with AI generated content" do
      visit("/latest")
      page.find("#create-topic").click

      composer.fill_content("This is a test")
      page.find(".composer-ai-helper").click

      expect(ai_helper_modal).to be_visible

      ai_helper_modal.choose_helper_model("proofreading")
    end
  end
end
