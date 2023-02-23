# frozen_string_literal: true

require "rails_helper"
require_relative "../../../support/sentiment_inference_stubs"

describe DiscourseAI::Sentiment::PostClassifier do
  fab!(:post) { Fabricate(:post) }

  before { SiteSetting.ai_sentiment_inference_service_api_endpoint = "http://test.com" }

  describe "#classify!" do
    it "stores each model classification in a post custom field" do
      SentimentInferenceStubs.stub_classification(post)

      subject.classify!(post)

      subject.available_models.each do |model|
        stored_classification = PostCustomField.find_by(post: post, name: "ai-sentiment-#{model}")
        expect(stored_classification).to be_present
        expect(stored_classification.value).to eq(
          { classification: SentimentInferenceStubs.model_response(model) }.to_json,
        )
      end
    end
  end
end
