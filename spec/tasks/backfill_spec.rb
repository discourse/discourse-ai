# frozen_string_literal: true

require_relative "../support/sentiment_inference_stubs"

RSpec.describe "assets:precompile" do
  before do
    Rake::Task.clear
    Discourse::Application.load_tasks
  end

  describe "ai:sentiment:backfill" do
    before { SiteSetting.ai_sentiment_inference_service_api_endpoint = "http://test.com" }

    it "does nothing if the topic is soft-deleted" do
      target = Fabricate(:post)
      SentimentInferenceStubs.stub_classification(target)
      target.topic.trash!

      path = Rake::Task["ai:sentiment:backfill"].invoke

      expect(ClassificationResult.count).to be_zero
    end
  end
end
