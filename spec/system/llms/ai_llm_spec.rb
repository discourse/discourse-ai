# frozen_string_literal: true

RSpec.describe "Managing LLM configurations", type: :system do
  fab!(:admin)

  before do
    SiteSetting.ai_bot_enabled = true
    sign_in(admin)
  end

  def select_preset(option)
    select_kit = PageObjects::Components::SelectKit.new(".ai-llm-editor__presets")

    select_kit.expand
    select_kit.select_row_by_value("anthropic-claude-3-haiku")

    find(".ai-llm-editor__next").click()
  end

  it "correctly sets defaults" do
    visit "/admin/plugins/discourse-ai/ai-llms"

    find(".ai-llms-list-editor__new").click()
    select_preset("anthropic-claude-3-haiku")

    find("input.ai-llm-editor__api-key").fill_in(with: "abcd")

    PageObjects::Components::DToggleSwitch.new(".ai-llm-editor__enabled-chat-bot").toggle

    find(".ai-llm-editor__save").click()

    expect(page).to have_current_path("/admin/plugins/discourse-ai/ai-llms")

    llm = LlmModel.order(:id).last
    expect(llm.api_key).to eq("abcd")

    preset = DiscourseAi::Completions::Llm.presets.find { |p| p[:id] == "anthropic" }

    model_preset = preset[:models].find { |m| m[:name] == "claude-3-haiku" }

    expect(llm.name).to eq("claude-3-haiku")
    expect(llm.url).to eq(preset[:endpoint])
    expect(llm.tokenizer).to eq(preset[:tokenizer].to_s)
    expect(llm.max_prompt_tokens.to_i).to eq(model_preset[:tokens])
    expect(llm.provider).to eq("anthropic")
    expect(llm.display_name).to eq(model_preset[:display_name])
    expect(llm.user_id).not_to be_nil
  end

  it "manually configures an LLM" do
    visit "/admin/plugins/discourse-ai/ai-llms"

    find(".ai-llms-list-editor__new").click()
    select_preset("none")

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

    PageObjects::Components::DToggleSwitch.new(".ai-llm-editor__enabled-chat-bot").toggle

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
end
