# frozen_string_literal: true

require_relative "../../support/openai_completions_inference_stubs"

RSpec.describe "AI Composer helper", type: :system, js: true do
  fab!(:user) { Fabricate(:admin) }

  before do
    Group.find_by(id: Group::AUTO_GROUPS[:admins]).add(user)
    SiteSetting.composer_ai_helper_enabled = true
    sign_in(user)
  end

  let(:composer) { PageObjects::Components::Composer.new }
  let(:ai_helper_context_menu) { PageObjects::Components::AIHelperContextMenu.new }
  let(:ai_helper_modal) { PageObjects::Modals::AiHelper.new }
  let(:diff_modal) { PageObjects::Modals::DiffModal.new }

  context "when using the translation mode" do
    let(:mode) { OpenAiCompletionsInferenceStubs::TRANSLATE }

    before { OpenAiCompletionsInferenceStubs.stub_prompt(mode) }

    it "replaces the composed message with AI generated content" do
      visit("/latest")
      page.find("#create-topic").click

      composer.fill_content(OpenAiCompletionsInferenceStubs.spanish_text)
      page.find(".composer-ai-helper").click

      expect(ai_helper_modal).to be_visible

      ai_helper_modal.select_helper_model(OpenAiCompletionsInferenceStubs.text_mode_to_id(mode))
      ai_helper_modal.save_changes

      expect(composer.composer_input.value).to eq(
        OpenAiCompletionsInferenceStubs.translated_response.strip,
      )
    end
  end

  context "when using the proofreading mode" do
    let(:mode) { OpenAiCompletionsInferenceStubs::PROOFREAD }

    before { OpenAiCompletionsInferenceStubs.stub_prompt(mode) }

    it "replaces the composed message with AI generated content" do
      visit("/latest")
      page.find("#create-topic").click

      composer.fill_content(OpenAiCompletionsInferenceStubs.translated_response)
      page.find(".composer-ai-helper").click

      expect(ai_helper_modal).to be_visible

      ai_helper_modal.select_helper_model(OpenAiCompletionsInferenceStubs.text_mode_to_id(mode))
      ai_helper_modal.save_changes

      expect(composer.composer_input.value).to eq(
        OpenAiCompletionsInferenceStubs.proofread_response.strip,
      )
    end
  end

  context "when selecting an AI generated title" do
    let(:mode) { OpenAiCompletionsInferenceStubs::GENERATE_TITLES }

    before { OpenAiCompletionsInferenceStubs.stub_prompt(mode) }

    it "replaces the topic title" do
      visit("/latest")
      page.find("#create-topic").click

      composer.fill_content(OpenAiCompletionsInferenceStubs.translated_response)
      page.find(".composer-ai-helper").click

      expect(ai_helper_modal).to be_visible

      ai_helper_modal.select_helper_model(OpenAiCompletionsInferenceStubs.text_mode_to_id(mode))
      ai_helper_modal.select_title_suggestion(2)
      ai_helper_modal.save_changes

      expected_title = "The Quiet Piece that Moves Literature: A Gaucho's Story"

      expect(find("#reply-title").value).to eq(expected_title)
    end
  end

  def trigger_context_menu(content)
    visit("/latest")
    page.find("#create-topic").click
    composer.fill_content(content)
    page.execute_script("document.querySelector('.d-editor-input')?.select();")
  end

  context "when triggering AI with context menu in composer" do
    it "shows the context menu when selecting a passage of text in the composer" do
      trigger_context_menu(OpenAiCompletionsInferenceStubs.translated_response)
      expect(ai_helper_context_menu).to have_context_menu
    end

    it "shows context menu in 'trigger' state when first showing" do
      trigger_context_menu(OpenAiCompletionsInferenceStubs.translated_response)
      expect(ai_helper_context_menu).to be_showing_triggers
    end

    it "shows prompt options in context menu when AI button is clicked" do
      trigger_context_menu(OpenAiCompletionsInferenceStubs.translated_response)
      ai_helper_context_menu.click_ai_button
      expect(ai_helper_context_menu).to be_showing_options
    end

    it "closes the context menu when clicking outside" do
      trigger_context_menu(OpenAiCompletionsInferenceStubs.translated_response)
      find(".d-editor-preview").click
      expect(ai_helper_context_menu).to have_no_context_menu
    end

    context "when using translation mode" do
      let(:mode) { OpenAiCompletionsInferenceStubs::TRANSLATE }
      before { OpenAiCompletionsInferenceStubs.stub_prompt(mode) }

      it "replaces the composed message with AI generated content" do
        trigger_context_menu(OpenAiCompletionsInferenceStubs.spanish_text)
        ai_helper_context_menu.click_ai_button
        ai_helper_context_menu.select_helper_model(
          OpenAiCompletionsInferenceStubs.text_mode_to_id(mode),
        )

        wait_for do
          composer.composer_input.value == OpenAiCompletionsInferenceStubs.translated_response.strip
        end

        expect(composer.composer_input.value).to eq(
          OpenAiCompletionsInferenceStubs.translated_response.strip,
        )
      end

      it "shows reset options after results are complete" do
        trigger_context_menu(OpenAiCompletionsInferenceStubs.spanish_text)
        ai_helper_context_menu.click_ai_button
        ai_helper_context_menu.select_helper_model(
          OpenAiCompletionsInferenceStubs.text_mode_to_id(mode),
        )

        wait_for do
          composer.composer_input.value == OpenAiCompletionsInferenceStubs.translated_response.strip
        end

        ai_helper_context_menu.click_confirm_button
        expect(ai_helper_context_menu).to be_showing_resets
      end

      it "reverts results when Undo button is clicked" do
        trigger_context_menu(OpenAiCompletionsInferenceStubs.spanish_text)
        ai_helper_context_menu.click_ai_button
        ai_helper_context_menu.select_helper_model(
          OpenAiCompletionsInferenceStubs.text_mode_to_id(mode),
        )

        wait_for do
          composer.composer_input.value == OpenAiCompletionsInferenceStubs.translated_response.strip
        end

        ai_helper_context_menu.click_confirm_button
        ai_helper_context_menu.click_undo_button
        expect(composer.composer_input.value).to eq(OpenAiCompletionsInferenceStubs.spanish_text)
      end

      it "reverts results when revert button is clicked" do
        trigger_context_menu(OpenAiCompletionsInferenceStubs.spanish_text)
        ai_helper_context_menu.click_ai_button
        ai_helper_context_menu.select_helper_model(
          OpenAiCompletionsInferenceStubs.text_mode_to_id(mode),
        )

        wait_for do
          composer.composer_input.value == OpenAiCompletionsInferenceStubs.translated_response.strip
        end

        ai_helper_context_menu.click_revert_button
        expect(composer.composer_input.value).to eq(OpenAiCompletionsInferenceStubs.spanish_text)
      end

      it "reverts results when Ctrl/Cmd + Z is pressed on the keyboard" do
        trigger_context_menu(OpenAiCompletionsInferenceStubs.spanish_text)
        ai_helper_context_menu.click_ai_button
        ai_helper_context_menu.select_helper_model(
          OpenAiCompletionsInferenceStubs.text_mode_to_id(mode),
        )

        wait_for do
          composer.composer_input.value == OpenAiCompletionsInferenceStubs.translated_response.strip
        end

        ai_helper_context_menu.press_undo_keys
        expect(composer.composer_input.value).to eq(OpenAiCompletionsInferenceStubs.spanish_text)
      end

      it "confirms the results when confirm button is pressed" do
        trigger_context_menu(OpenAiCompletionsInferenceStubs.spanish_text)
        ai_helper_context_menu.click_ai_button
        ai_helper_context_menu.select_helper_model(
          OpenAiCompletionsInferenceStubs.text_mode_to_id(mode),
        )

        wait_for do
          composer.composer_input.value == OpenAiCompletionsInferenceStubs.translated_response.strip
        end

        ai_helper_context_menu.click_confirm_button
        expect(composer.composer_input.value).to eq(
          OpenAiCompletionsInferenceStubs.translated_response.strip,
        )
      end

      it "hides the context menu when pressing Escape on the keyboard" do
        trigger_context_menu(OpenAiCompletionsInferenceStubs.spanish_text)
        ai_helper_context_menu.click_ai_button
        ai_helper_context_menu.press_escape_key
        expect(ai_helper_context_menu).to have_no_context_menu
      end

      it "shows the changes in a modal when view changes button is pressed" do
        trigger_context_menu(OpenAiCompletionsInferenceStubs.spanish_text)
        ai_helper_context_menu.click_ai_button
        ai_helper_context_menu.select_helper_model(
          OpenAiCompletionsInferenceStubs.text_mode_to_id(mode),
        )

        wait_for do
          composer.composer_input.value == OpenAiCompletionsInferenceStubs.translated_response.strip
        end

        ai_helper_context_menu.click_view_changes_button
        expect(diff_modal).to be_visible
        expect(diff_modal.old_value).to eq(
          OpenAiCompletionsInferenceStubs.spanish_text.gsub(/[[:space:]]+/, " ").strip,
        )
        expect(diff_modal.new_value).to eq(
          OpenAiCompletionsInferenceStubs
            .translated_response
            .gsub(/[[:space:]]+/, " ")
            .gsub(/[‘’]/, "'")
            .gsub(/[“”]/, '"')
            .strip,
        )
        diff_modal.confirm_changes
        expect(ai_helper_context_menu).to be_showing_resets
      end

      it "should not close the context menu when in review state" do
        trigger_context_menu(OpenAiCompletionsInferenceStubs.spanish_text)
        ai_helper_context_menu.click_ai_button
        ai_helper_context_menu.select_helper_model(
          OpenAiCompletionsInferenceStubs.text_mode_to_id(mode),
        )

        wait_for do
          composer.composer_input.value == OpenAiCompletionsInferenceStubs.translated_response.strip
        end

        find(".d-editor-preview").click
        expect(ai_helper_context_menu).to have_context_menu
      end
    end

    context "when using the proofreading mode" do
      let(:mode) { OpenAiCompletionsInferenceStubs::PROOFREAD }
      before { OpenAiCompletionsInferenceStubs.stub_prompt(mode) }

      it "replaces the composed message with AI generated content" do
        trigger_context_menu(OpenAiCompletionsInferenceStubs.translated_response)
        ai_helper_context_menu.click_ai_button
        ai_helper_context_menu.select_helper_model(
          OpenAiCompletionsInferenceStubs.text_mode_to_id(mode),
        )

        wait_for do
          composer.composer_input.value == OpenAiCompletionsInferenceStubs.proofread_response.strip
        end

        expect(composer.composer_input.value).to eq(
          OpenAiCompletionsInferenceStubs.proofread_response.strip,
        )
      end
    end

    context "when selecting an AI generated title" do
      let(:mode) { OpenAiCompletionsInferenceStubs::GENERATE_TITLES }
      before { OpenAiCompletionsInferenceStubs.stub_prompt(mode) }

      it "replaces the topic title" do
        trigger_context_menu(OpenAiCompletionsInferenceStubs.translated_response)
        ai_helper_context_menu.click_ai_button
        ai_helper_context_menu.select_helper_model(
          OpenAiCompletionsInferenceStubs.text_mode_to_id(mode),
        )
        expect(ai_helper_context_menu).to be_showing_suggestions

        ai_helper_context_menu.select_title_suggestion(2)
        expected_title = "The Quiet Piece that Moves Literature: A Gaucho's Story"

        wait_for { find("#reply-title").value == expected_title }
        expect(find("#reply-title").value).to eq(expected_title)
      end
    end
  end
end
