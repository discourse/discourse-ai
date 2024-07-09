# frozen_string_literal: true

require "rails_helper"

describe "AI Tool Management", type: :system do
  fab!(:admin)

  before do
    SiteSetting.ai_embeddings_enabled = true
    sign_in(admin)
  end

  it "allows admin to create a new AI tool from preset" do
    visit "/admin/plugins/discourse-ai/ai-tools"

    expect(page).to have_content("Tools")

    find(".ai-tool-list-editor__new-button").click

    select_kit = PageObjects::Components::SelectKit.new(".ai-tool-editor__presets")
    select_kit.expand
    select_kit.select_row_by_value("exchange_rate")

    find(".ai-tool-editor__next").click
    find(".ai-tool-editor__test-button").click

    expect(page).not_to have_button(".ai-tool-editor__delete")

    modal = PageObjects::Modals::AiToolTest.new
    modal.base_currency = "USD"
    modal.target_currency = "EUR"
    modal.amount = "100"

    stub_request(:get, %r{https://open\.er-api\.com/v6/latest/USD}).to_return(
      status: 200,
      body: '{"rates": {"EUR": 0.85}}',
      headers: {
        "Content-Type" => "application/json",
      },
    )
    modal.run_test

    expect(modal).to have_content("exchange_rate")
    expect(modal).to have_content("0.85")

    modal.close

    find(".ai-tool-editor__save").click

    expect(page).to have_content("Tool saved")

    visit "/admin/plugins/discourse-ai/ai-personas/new"

    tool_id = AiTool.order("id desc").limit(1).pluck(:id).first
    tool_selector = PageObjects::Components::SelectKit.new(".ai-persona-editor__tools")
    tool_selector.expand

    tool_selector.select_row_by_value("custom-#{tool_id}")
    expect(tool_selector).to have_selected_value("custom-#{tool_id}")
  end
end
