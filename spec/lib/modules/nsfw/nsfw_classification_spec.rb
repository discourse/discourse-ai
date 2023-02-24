# frozen_string_literal: true

require "rails_helper"
require_relative "../../../support/nsfw_inference_stubs"

describe DiscourseAI::NSFW::NSFWClassification do
  before { SiteSetting.ai_nsfw_inference_service_api_endpoint = "http://test.com" }

  let(:available_models) { SiteSetting.ai_nsfw_models.split("|") }

  describe "#request" do
    fab!(:upload_1) { Fabricate(:s3_image_upload) }
    fab!(:post) { Fabricate(:post, uploads: [upload_1]) }

    def assert_correctly_classified(upload, results, expected)
      available_models.each do |model|
        model_result = results.dig(upload.id, model)

        expect(model_result).to eq(expected[model])
      end
    end

    def build_expected_classification(positive: true)
      available_models.reduce({}) do |memo, model|
        model_expected =
          if positive
            NSFWInferenceStubs.positive_result(model)
          else
            NSFWInferenceStubs.negative_result(model)
          end

        memo[model] = model_expected
        memo
      end
    end

    context "when the target has one upload" do
      it "returns the classification and the model used for it" do
        NSFWInferenceStubs.positive(upload_1)
        expected = build_expected_classification

        classification = subject.request(post)

        assert_correctly_classified(upload_1, classification, expected)
      end

      context "when the target has multiple uploads" do
        fab!(:upload_2) { Fabricate(:upload) }

        before { post.uploads << upload_2 }

        it "returns a classification for each one" do
          NSFWInferenceStubs.positive(upload_1)
          NSFWInferenceStubs.negative(upload_2)
          expected_upload_1 = build_expected_classification
          expected_upload_2 = build_expected_classification(positive: false)

          classification = subject.request(post)

          assert_correctly_classified(upload_1, classification, expected_upload_1)
          assert_correctly_classified(upload_2, classification, expected_upload_2)
        end
      end
    end
  end

  describe "#should_flag_based_on?" do
    before { SiteSetting.ai_nsfw_flag_automatically = true }

    let(:positive_classification) do
      {
        1 => available_models.map { |m| { m => NSFWInferenceStubs.negative_result(m) } },
        2 => available_models.map { |m| { m => NSFWInferenceStubs.positive_result(m) } },
      }
    end

    let(:negative_classification) do
      {
        1 => available_models.map { |m| { m => NSFWInferenceStubs.negative_result(m) } },
        2 => available_models.map { |m| { m => NSFWInferenceStubs.negative_result(m) } },
      }
    end

    it "returns false when NSFW flaggin is disabled" do
      SiteSetting.ai_nsfw_flag_automatically = false

      should_flag = subject.should_flag_based_on?(positive_classification)

      expect(should_flag).to eq(false)
    end

    it "returns true if the response is NSFW based on our thresholds" do
      should_flag = subject.should_flag_based_on?(positive_classification)

      expect(should_flag).to eq(true)
    end

    it "returns false if the response is safe based on our thresholds" do
      should_flag = subject.should_flag_based_on?(negative_classification)

      expect(should_flag).to eq(false)
    end
  end
end
