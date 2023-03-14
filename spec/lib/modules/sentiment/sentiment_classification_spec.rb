# frozen_string_literal: true

require "rails_helper"
require_relative "../../../support/sentiment_inference_stubs"

describe DiscourseAi::Sentiment::SentimentClassification do
  fab!(:target) { Fabricate(:post) }

  describe "#request" do
    before { SiteSetting.ai_sentiment_inference_service_api_endpoint = "http://test.com" }

    it "returns the classification and the model used for it" do
      SentimentInferenceStubs.stub_classification(target)

      result = subject.request(target)

      subject.available_models.each do |model|
        expect(result[model]).to eq(SentimentInferenceStubs.model_response(model))
      end
    end
  end
end
