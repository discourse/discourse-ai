# frozen_string_literal: true

RSpec.describe "Managing LLM configurations", type: :system, js: true do
  fab!(:admin)
  let(:page_header) { PageObjects::Components::DPageHeader.new }

  before do
    SiteSetting.ai_bot_enabled = true
    sign_in(admin)
  end

  it "correctly sets defaults" do
    visit "/admin/plugins/discourse-ai/ai-llms"

    find("[data-llm-id='anthropic-claude-3-5-haiku'] button").click()
    find("input.ai-llm-editor__api-key").fill_in(with: "abcd")
    find(".ai-llm-editor__enabled-chat-bot input").click
    find(".ai-llm-editor__save").click()

    expect(page).to have_current_path("/admin/plugins/discourse-ai/ai-llms")

    llm = LlmModel.order(:id).last
    expect(llm.api_key).to eq("abcd")

    preset = DiscourseAi::Completions::Llm.presets.find { |p| p[:id] == "anthropic" }

    model_preset = preset[:models].find { |m| m[:name] == "claude-3-5-haiku" }

    expect(llm.name).to eq("claude-3-5-haiku")
    expect(llm.url).to eq(preset[:endpoint])
    expect(llm.tokenizer).to eq(preset[:tokenizer].to_s)
    expect(llm.max_prompt_tokens.to_i).to eq(model_preset[:tokens])
    expect(llm.provider).to eq("anthropic")
    expect(llm.display_name).to eq(model_preset[:display_name])
    expect(llm.user_id).not_to be_nil
  end

  it "manually configures an LLM" do
    visit "/admin/plugins/discourse-ai/ai-llms"
    expect(page_header).to be_visible

    find("[data-llm-id='none'] button").click()
    expect(page_header).to be_hidden

    find("input.ai-llm-editor__display-name").fill_in(with: "Self-hosted LLM")
    find("input.ai-llm-editor__name").fill_in(with: "llava-hf/llava-v1.6-mistral-7b-hf")
    find("input.ai-llm-editor__url").fill_in(with: "srv://self-hostest.test")
    find("input.ai-llm-editor__api-key").fill_in(with: "1234")
    find("input.ai-llm-editor__max-prompt-tokens").fill_in(with: 8000)

    find(".ai-llm-editor__provider").click
    find(".select-kit-row[data-value=\"vllm\"]").click

    find(".ai-llm-editor__tokenizer").click
    find(".select-kit-row[data-name=\"Llama3Tokenizer\"]").click

    find(".ai-llm-editor__vision-enabled input").click
    find(".ai-llm-editor__enabled-chat-bot input").click

    find(".ai-llm-editor__save").click()

    expect(page).to have_current_path("/admin/plugins/discourse-ai/ai-llms")

    llm = LlmModel.order(:id).last

    expect(llm.display_name).to eq("Self-hosted LLM")
    expect(llm.name).to eq("llava-hf/llava-v1.6-mistral-7b-hf")
    expect(llm.url).to eq("srv://self-hostest.test")
    expect(llm.tokenizer).to eq("DiscourseAi::Tokenizer::Llama3Tokenizer")
    expect(llm.max_prompt_tokens.to_i).to eq(8000)
    expect(llm.provider).to eq("vllm")
    expect(llm.vision_enabled).to eq(true)
    expect(llm.user_id).not_to be_nil
  end

  context "when seeded LLM is present" do
    fab!(:llm_model) { Fabricate(:seeded_model) }

    it "shows the provider as CDCK in the UI" do
      visit "/admin/plugins/discourse-ai/ai-llms"
      expect(page).to have_css(
        "[data-llm-id='cdck-hosted']",
        text: I18n.t("js.discourse_ai.llms.providers.CDCK"),
      )
    end

    it "seeded LLM has a description" do
      visit "/admin/plugins/discourse-ai/ai-llms"

      description =
        I18n.t("js.discourse_ai.llms.preseeded_model_description", model: llm_model.name)

      expect(page).to have_css(
        "[data-llm-id='#{llm_model.name}'] .ai-llm-list__description",
        text: description,
      )
    end

    it "seeded LLM has a disabled edit button" do
      visit "/admin/plugins/discourse-ai/ai-llms"
      expect(page).to have_css("[data-llm-id='cdck-hosted'] .ai-llm-list__edit-disabled-tooltip")
    end
  end
end
