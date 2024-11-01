# frozen_string_literal: true

require_relative "../../../support/sentiment_inference_stubs"

describe DiscourseAi::Sentiment::SentimentClassification do
  fab!(:target) { Fabricate(:post) }

  describe "#request" do
    before do
      SiteSetting.ai_sentiment_model_configs =
        "[{\"model_name\":\"SamLowe/roberta-base-go_emotions\",\"endpoint\":\"http://samlowe-emotion.com\",\"api_key\":\"123\"},{\"model_name\":\"j-hartmann/emotion-english-distilroberta-base\",\"endpoint\":\"http://jhartmann-emotion.com\",\"api_key\":\"123\"},{\"model_name\":\"cardiffnlp/twitter-roberta-base-sentiment-latest\",\"endpoint\":\"http://cardiffnlp-sentiment.com\",\"api_key\":\"123\"}]"
    end

    it "returns the classification and the model used for it" do
      SentimentInferenceStubs.stub_classification(target)

      result = subject.request(target)

      subject.available_classifiers.each do |model_config|
        expect(result[model_config.model_name]).to eq(
          subject.transform_result(SentimentInferenceStubs.model_response(model_config.model_name)),
        )
      end
    end
  end
end
