# frozen_string_literal: true

require_relative "../../support/summarization_stubs"

RSpec.describe "AI chat channel summarization", type: :system, js: true do
  fab!(:user) { Fabricate(:leader) }
  fab!(:channel) { Fabricate(:chat_channel) }

  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel) }
  fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel) }
  fab!(:message_3) { Fabricate(:chat_message, chat_channel: channel) }

  before do
    sign_in(user)
    chat_system_bootstrap(user, [channel])
    SiteSetting.ai_summarization_enabled = true
    SiteSetting.ai_summarization_model = "gpt-4"
  end

  let(:summarization_modal) { PageObjects::Modals::Summarization.new }

  it "returns a summary using the selected timeframe" do
    visit("/chat/c/-/#{channel.id}")

    SummarizationStubs.openai_chat_summarization_stub([message_1, message_2, message_3])

    find(".chat-composer-dropdown__trigger-btn").click
    find(".chat-composer-dropdown__action-btn.chat_channel_summary").click

    expect(summarization_modal).to be_visible

    summarization_modal.select_timeframe("3")

    expect(summarization_modal.summary_value).to eq(SummarizationStubs.test_summary)
  end
end
