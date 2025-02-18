# frozen_string_literal: true

RSpec.describe DiscourseAi::Sentiment::SentimentAnalysisReport do
  fab!(:user_1) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }
  fab!(:post_1) { Fabricate(:post, user: user_1) }
  fab!(:post_2) { Fabricate(:post, user: user_2) }

  before do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_embeddings_enabled = false
  end

  it "contains the correct filters" do
    report = Report.find("sentiment_analysis")
    pp report.availble_filters.keys
  end
end
