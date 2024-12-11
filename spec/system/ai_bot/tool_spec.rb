# frozen_string_literal: true

require "rails_helper"

describe "AI Tool Management", type: :system do
  fab!(:admin)
  let(:admin_header) { PageObjects::Components::AdminHeader.new }

  before do
    SiteSetting.ai_embeddings_enabled = true
    sign_in(admin)
  end

  def ensure_can_run_test
    find(".ai-tool-editor__test-button").click

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
  end

  it "allows admin to create a new AI tool from preset" do
    visit "/admin/plugins/discourse-ai/ai-tools"

    expect(admin_header).to be_visible
    expect(page).to have_content("Tools")

    find(".ai-tool-list-editor__new-button").click
    expect(admin_header).to be_hidden

    select_kit = PageObjects::Components::SelectKit.new(".ai-tool-editor__presets")
    select_kit.expand
    select_kit.select_row_by_value("exchange_rate")

    find(".ai-tool-editor__next").click

    expect(page.first(".parameter-row__required-toggle").checked?).to eq(true)
    expect(page.first(".parameter-row__enum-toggle").checked?).to eq(false)

    # not allowed to test yet
    expect(page).not_to have_button(".ai-tool-editor__test-button")

    expect(page).not_to have_button(".ai-tool-editor__delete")
    find(".ai-tool-editor__save").click

    expect(page).to have_content("Tool saved")

    last_tool = AiTool.order("id desc").limit(1).first
    visit "/admin/plugins/discourse-ai/ai-tools/#{last_tool.id}"

    ensure_can_run_test

    expect(page.first(".parameter-row__required-toggle").checked?).to eq(true)
    expect(page.first(".parameter-row__enum-toggle").checked?).to eq(false)

    visit "/admin/plugins/discourse-ai/ai-personas/new"

    tool_id = AiTool.order("id desc").limit(1).pluck(:id).first
    tool_selector = PageObjects::Components::SelectKit.new(".ai-persona-editor__tools")
    tool_selector.expand

    tool_selector.select_row_by_value("custom-#{tool_id}")
    expect(tool_selector).to have_selected_value("custom-#{tool_id}")
  end
end
