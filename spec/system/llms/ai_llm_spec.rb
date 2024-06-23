# frozen_string_literal: true

RSpec.describe "Admin dashboard", type: :system do
  fab!(:admin)

  it "correctly sets defaults" do
    SiteSetting.ai_bot_enabled = true

    sign_in(admin)

    visit "/admin/plugins/discourse-ai/ai-llms"

    find(".ai-llms-list-editor__new").click()

    select_kit = PageObjects::Components::SelectKit.new(".ai-llm-editor__presets")

    select_kit.expand
    select_kit.select_row_by_value("anthropic-claude-3-haiku")

    find(".ai-llm-editor__next").click()
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
end
