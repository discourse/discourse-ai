# frozen_string_literal: true

require "rails_helper"
require_relative "../support/sentiment_inference_stubs"

describe DiscourseAi::Classificator do
  describe "#classify!" do
    describe "saving the classification result" do
      let(:classification_raw_result) do
        model
          .available_models
          .reduce({}) do |memo, model_name|
            memo[model_name] = SentimentInferenceStubs.model_response(model_name)
            memo
          end
      end

      let(:model) { DiscourseAi::Sentiment::SentimentClassification.new }
      let(:classification) { DiscourseAi::PostClassificator.new(model) }
      fab!(:target) { Fabricate(:post) }

      before do
        SiteSetting.ai_sentiment_model_configs =
          "[{\"model_name\":\"SamLowe/roberta-base-go_emotions\",\"endpoint\":\"http://samlowe-emotion.com\",\"api_key\":\"123\"},{\"model_name\":\"j-hartmann/emotion-english-distilroberta-base\",\"endpoint\":\"http://jhartmann-emotion.com\",\"api_key\":\"123\"},{\"model_name\":\"cardiffnlp/twitter-roberta-base-sentiment-latest\",\"endpoint\":\"http://cardiffnlp-sentiment.com\",\"api_key\":\"123\"}]"
        SentimentInferenceStubs.stub_classification(target)
      end

      it "stores one result per model used" do
        classification.classify!(target)

        stored_results = ClassificationResult.where(target: target)
        expect(stored_results.length).to eq(model.available_models.length)

        model.available_models.each do |model_name|
          result = stored_results.detect { |c| c.model_used == model_name }

          expect(result.classification_type).to eq(model.type.to_s)
          expect(result.created_at).to be_present
          expect(result.updated_at).to be_present

          expected_classification = SentimentInferenceStubs.model_response(model)

          expect(result.classification.deep_symbolize_keys).to eq(expected_classification)
        end
      end

      it "updates an existing classification result" do
        original_creation = 3.days.ago

        model.available_models.each do |model_name|
          ClassificationResult.create!(
            target: target,
            model_used: model_name,
            classification_type: model.type,
            created_at: original_creation,
            updated_at: original_creation,
            classification: {
            },
          )
        end

        classification.classify!(target)

        stored_results = ClassificationResult.where(target: target)
        expect(stored_results.length).to eq(model.available_models.length)

        model.available_models.each do |model_name|
          result = stored_results.detect { |c| c.model_used == model_name }

          expect(result.classification_type).to eq(model.type.to_s)
          expect(result.updated_at).to be > original_creation
          expect(result.created_at).to eq_time(original_creation)

          expect(result.classification.deep_symbolize_keys).to eq(
            classification_raw_result[model_name],
          )
        end
      end
    end
  end
end
