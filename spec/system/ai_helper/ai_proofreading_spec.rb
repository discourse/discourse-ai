# frozen_string_literal: true

include SystemHelpers

RSpec.describe "AI Composer Proofreading Features", type: :system, js: true do
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }

  before do
    assign_fake_provider_to(:ai_helper_model)
    SiteSetting.ai_helper_enabled = true
    sign_in(admin)
  end

  let(:composer) { PageObjects::Components::Composer.new }
  let(:toasts) { PageObjects::Components::Toasts.new }
  let(:diff_modal) { PageObjects::Modals::DiffModal.new }

  context "when triggering via keyboard shortcut" do
    it "proofreads selected text using" do
      skip("Message bus updates not appearing in tests")
      visit "/new-topic"
      composer.fill_content("hello worldd !")

      composer.select_range(6, 12)

      DiscourseAi::Completions::Llm.with_prepared_responses(["world"]) do
        composer.composer_input.send_keys([PLATFORM_KEY_MODIFIER, :alt, "p"])
        diff_modal.confirm_changes
        expect(composer.composer_input.value).to eq("hello world !")
      end
    end

    it "proofreads all text when nothing is selected" do
      skip("Message bus updates not appearing in tests")
      visit "/new-topic"
      composer.fill_content("hello worrld")

      # Simulate AI response
      DiscourseAi::Completions::Llm.with_prepared_responses(["hello world"]) do
        composer.composer_input.send_keys([PLATFORM_KEY_MODIFIER, :alt, "p"])
        diff_modal.confirm_changes
        expect(composer.composer_input.value).to eq("hello world")
      end
    end

    it "does not trigger proofread modal if composer is empty" do
      visit "/new-topic"

      # Simulate AI response
      DiscourseAi::Completions::Llm.with_prepared_responses(["hello world"]) do
        composer.composer_input.send_keys([PLATFORM_KEY_MODIFIER, :alt, "p"])
        expect(toasts).to have_error(I18n.t("js.discourse_ai.ai_helper.no_content_error"))
      end
    end
  end
end
