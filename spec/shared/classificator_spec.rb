# frozen_string_literal: true

require "rails_helper"
require_relative "../support/sentiment_inference_stubs"

describe DiscourseAi::Classificator do
  describe "#classify!" do
    describe "saving the classification result" do
      let(:model) { DiscourseAi::Sentiment::SentimentClassification.new }

      let(:classification_raw_result) do
        model
          .available_classifiers
          .reduce({}) do |memo, model_config|
            memo[model_config.model_name] = model.transform_result(
              SentimentInferenceStubs.model_response(model_config.model_name),
            )
            memo
          end
      end

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
        expect(stored_results.length).to eq(model.available_classifiers.length)

        model.available_classifiers.each do |model_config|
          result = stored_results.detect { |c| c.model_used == model_config.model_name }

          expect(result.classification_type).to eq(model.type.to_s)
          expect(result.created_at).to be_present
          expect(result.updated_at).to be_present

          expected_classification = SentimentInferenceStubs.model_response(model_config.model_name)
          transformed_classification = model.transform_result(expected_classification)

          expect(result.classification).to eq(transformed_classification)
        end
      end

      it "updates an existing classification result" do
        original_creation = 3.days.ago

        model.available_classifiers.each do |model_config|
          ClassificationResult.create!(
            target: target,
            model_used: model_config.model_name,
            classification_type: model.type,
            created_at: original_creation,
            updated_at: original_creation,
            classification: {
            },
          )
        end

        classification.classify!(target)

        stored_results = ClassificationResult.where(target: target)
        expect(stored_results.length).to eq(model.available_classifiers.length)

        model.available_classifiers.each do |model_config|
          result = stored_results.detect { |c| c.model_used == model_config.model_name }

          expect(result.classification_type).to eq(model.type.to_s)
          expect(result.updated_at).to be > original_creation
          expect(result.created_at).to eq_time(original_creation)

          expect(result.classification).to eq(classification_raw_result[model_config.model_name])
        end
      end
    end
  end
end
