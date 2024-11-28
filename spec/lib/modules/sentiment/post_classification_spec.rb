# frozen_string_literal: true

require_relative "../../../support/sentiment_inference_stubs"

RSpec.describe DiscourseAi::Sentiment::PostClassification do
  fab!(:post_1) { Fabricate(:post, post_number: 2) }

  before do
    SiteSetting.ai_sentiment_enabled = true
    SiteSetting.ai_sentiment_model_configs =
      "[{\"model_name\":\"SamLowe/roberta-base-go_emotions\",\"endpoint\":\"http://samlowe-emotion.com\",\"api_key\":\"123\"},{\"model_name\":\"j-hartmann/emotion-english-distilroberta-base\",\"endpoint\":\"http://jhartmann-emotion.com\",\"api_key\":\"123\"},{\"model_name\":\"cardiffnlp/twitter-roberta-base-sentiment-latest\",\"endpoint\":\"http://cardiffnlp-sentiment.com\",\"api_key\":\"123\"}]"
  end

  describe "#classify!" do
    it "does nothing if the post content is blank" do
      post_1.update_columns(raw: "")

      subject.classify!(post_1)

      expect(ClassificationResult.where(target: post_1).count).to be_zero
    end

    it "successfully classifies the post" do
      expected_analysis = DiscourseAi::Sentiment::SentimentSiteSettingJsonSchema.values.length
      SentimentInferenceStubs.stub_classification(post_1)

      subject.classify!(post_1)

      expect(ClassificationResult.where(target: post_1).count).to eq(expected_analysis)
    end
  end

  describe "#classify_bulk!" do
    fab!(:post_2) { Fabricate(:post, post_number: 2) }

    it "classifies all given posts" do
      expected_analysis = DiscourseAi::Sentiment::SentimentSiteSettingJsonSchema.values.length
      SentimentInferenceStubs.stub_classification(post_1)
      SentimentInferenceStubs.stub_classification(post_2)

      subject.bulk_classify!(Post.where(id: [post_1.id, post_2.id]))

      expect(ClassificationResult.where(target: post_1).count).to eq(expected_analysis)
      expect(ClassificationResult.where(target: post_2).count).to eq(expected_analysis)
    end
  end
end
