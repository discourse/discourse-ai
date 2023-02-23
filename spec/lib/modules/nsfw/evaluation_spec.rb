# frozen_string_literal: true

require "rails_helper"
require_relative "../../../support/nsfw_inference_stubs"

describe DiscourseAI::NSFW::Evaluation do
  before { SiteSetting.ai_nsfw_live_detection_enabled = true }

  fab!(:image) { Fabricate(:s3_image_upload) }

  let(:available_models) { DiscourseAI::NSFW::Evaluation::AVAILABLE_MODELS }

  describe "perform" do
    context "when we determine content is NSFW" do
      before { NSFWInferenceStubs.positive(image) }

      it "returns true alongside the evaluation" do
        result = subject.perform(image)

        expect(result[:verdict]).to eq(true)

        available_models.each do |model|
          expect(result.dig(:evaluation, model.to_sym)).to eq(
            NSFWInferenceStubs.positive_result(model),
          )
        end
      end
    end

    context "when we determine content is safe" do
      before { NSFWInferenceStubs.negative(image) }

      it "returns false alongside the evaluation" do
        result = subject.perform(image)

        expect(result[:verdict]).to eq(false)

        available_models.each do |model|
          expect(result.dig(:evaluation, model.to_sym)).to eq(
            NSFWInferenceStubs.negative_result(model),
          )
        end
      end
    end
  end
end
