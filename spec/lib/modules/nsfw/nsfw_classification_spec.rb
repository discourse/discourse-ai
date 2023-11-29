# frozen_string_literal: true

require "rails_helper"
require_relative "../../../support/nsfw_inference_stubs"

describe DiscourseAi::Nsfw::Classification do
  before { SiteSetting.ai_nsfw_inference_service_api_endpoint = "http://test.com" }

  let(:available_models) { SiteSetting.ai_nsfw_models.split("|") }

  fab!(:upload_1) { Fabricate(:s3_image_upload) }
  fab!(:post) { Fabricate(:post, uploads: [upload_1]) }

  describe "#request" do
    def assert_correctly_classified(results, expected)
      available_models.each { |model| expect(results[model]).to eq(expected[model]) }
    end

    def build_expected_classification(target, positive: true)
      available_models.reduce({}) do |memo, model|
        model_expected =
          if positive
            NSFWInferenceStubs.positive_result(model)
          else
            NSFWInferenceStubs.negative_result(model)
          end

        memo[model] = {
          target.id => model_expected.merge(target_classified_type: target.class.name),
        }
        memo
      end
    end

    context "when the target has one upload" do
      it "returns the classification and the model used for it" do
        NSFWInferenceStubs.positive(upload_1)
        expected = build_expected_classification(upload_1)

        classification = subject.request(post)

        assert_correctly_classified(classification, expected)
      end

      context "when the target has multiple uploads" do
        fab!(:upload_2) { Fabricate(:upload) }

        before { post.uploads << upload_2 }

        it "returns a classification for each one" do
          NSFWInferenceStubs.positive(upload_1)
          NSFWInferenceStubs.negative(upload_2)
          expected_classification = build_expected_classification(upload_1)
          expected_classification.deep_merge!(
            build_expected_classification(upload_2, positive: false),
          )

          classification = subject.request(post)

          assert_correctly_classified(classification, expected_classification)
        end

        it "correctly skips unsupported uploads" do
          NSFWInferenceStubs.positive(upload_1)
          NSFWInferenceStubs.unsupported(upload_2)
          expected_classification = build_expected_classification(upload_1)

          classification = subject.request(post)

          assert_correctly_classified(classification, expected_classification)
        end
      end
    end
  end

  describe "#should_flag_based_on?" do
    before { SiteSetting.ai_nsfw_flag_automatically = true }

    let(:positive_verdict) { { "opennsfw2" => true, "nsfw_detector" => true } }

    let(:negative_verdict) { { "opennsfw2" => false } }

    it "returns false when NSFW flaggin is disabled" do
      SiteSetting.ai_nsfw_flag_automatically = false

      should_flag = subject.should_flag_based_on?(positive_verdict)

      expect(should_flag).to eq(false)
    end

    it "returns true if the response is NSFW based on our thresholds" do
      should_flag = subject.should_flag_based_on?(positive_verdict)

      expect(should_flag).to eq(true)
    end

    it "returns false if the response is safe based on our thresholds" do
      should_flag = subject.should_flag_based_on?(negative_verdict)

      expect(should_flag).to eq(false)
    end
  end
end
