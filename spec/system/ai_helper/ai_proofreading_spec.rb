# frozen_string_literal: true

RSpec.describe "AI Composer Proofreading Features", type: :system, js: true do
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }

  before do
    assign_fake_provider_to(:ai_helper_model)
    SiteSetting.ai_helper_enabled = true
    sign_in(admin)
  end

  let(:composer) { PageObjects::Components::Composer.new }

  it "proofreads selected text using the composer toolbar" do
    visit "/new-topic"
    composer.fill_content("hello worldd !")

    composer.select_range(6, 12)

    DiscourseAi::Completions::Llm.with_prepared_responses(["world"]) do
      ai_toolbar = PageObjects::Components::SelectKit.new(".toolbar-popup-menu-options")
      ai_toolbar.expand
      ai_toolbar.select_row_by_name("Proofread Text")

      find(".composer-ai-helper-modal .btn-primary.confirm").click
      expect(composer.composer_input.value).to eq("hello world !")
    end
  end

  it "proofreads all text when nothing is selected" do
    visit "/new-topic"
    composer.fill_content("hello worrld")

    # Simulate AI response
    DiscourseAi::Completions::Llm.with_prepared_responses(["hello world"]) do
      ai_toolbar = PageObjects::Components::SelectKit.new(".toolbar-popup-menu-options")
      ai_toolbar.expand
      ai_toolbar.select_row_by_name("Proofread Text")

      find(".composer-ai-helper-modal .btn-primary.confirm").click
      expect(composer.composer_input.value).to eq("hello world")
    end
  end
end
