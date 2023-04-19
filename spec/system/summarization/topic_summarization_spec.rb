# frozen_string_literal: true

require_relative "../../support/summarization_stubs"

RSpec.describe "AI chat channel summarization", type: :system, js: true do
  fab!(:user) { Fabricate(:leader) }
  fab!(:topic) { Fabricate(:topic, has_summary: true) }

  fab!(:post_1) { Fabricate(:post, topic: topic) }
  fab!(:post_2) { Fabricate(:post, topic: topic) }

  before do
    sign_in(user)
    SiteSetting.ai_summarization_enabled = true
    SiteSetting.ai_summarization_model = "gpt-4"
  end

  let(:summarization_modal) { PageObjects::Modals::Summarization.new }

  it "returns a summary using the selected timeframe" do
    visit("/t/-/#{topic.id}")

    SummarizationStubs.openai_topic_summarization_stub(topic, user)

    find(".topic-ai-summarization").click

    expect(summarization_modal).to be_visible

    summarization_modal.generate_summary

    expect(summarization_modal.summary_value).to eq(SummarizationStubs.test_summary)
  end
end
