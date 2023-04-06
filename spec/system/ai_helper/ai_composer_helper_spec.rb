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
  let(:ai_helper_modal) { PageObjects::Modals::AiHelper.new }

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
end
