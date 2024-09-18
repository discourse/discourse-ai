# frozen_string_literal: true

RSpec.describe "Summarize a topic ", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:group)
  fab!(:topic)
  fab!(:post) do
    Fabricate(
      :post,
      topic: topic,
      raw:
        "I like to eat pie. It is a very good dessert. Some people are wasteful by throwing pie at others but I do not do that. I always eat the pie.",
    )
  end
  let(:summarization_result) { "This is a summary" }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    group.add(current_user)

    assign_fake_provider_to(:ai_summarization_model)
    SiteSetting.ai_summarization_enabled = true
    SiteSetting.ai_custom_summarization_allowed_groups = group.id.to_s

    sign_in(current_user)
  end

  context "when a summary is cached" do
    before do
      AiSummary.create!(
        target: topic,
        summarized_text: summarization_result,
        algorithm: "test",
        original_content_sha: "test",
      )
    end

    it "displays it" do
      topic_page.visit_topic(topic)

      find(".ai-summarization-button button").click

      expect(find(".generated-summary p").text).to eq(summarization_result)
    end
  end
end
