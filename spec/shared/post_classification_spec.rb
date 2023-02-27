# frozen_string_literal: true

require "rails_helper"
require_relative "../support/toxicity_inference_stubs"

describe DiscourseAI::PostClassification do
  fab!(:post) { Fabricate(:post) }

  let(:model) { DiscourseAI::Toxicity::ToxicityClassification.new }
  let(:classification) { described_class.new(model) }

  describe "#classify!" do
    before { ToxicityInferenceStubs.stub_post_classification(post, toxic: true) }

    it "stores the model classification data" do
      classification.classify!(post)
      result = ClassificationResult.find_by(target: post, classification_type: model.type)

      classification = result.classification.symbolize_keys

      expect(classification).to eq(ToxicityInferenceStubs.toxic_response)
    end

    it "flags the message and hides the post when the model decides we should" do
      SiteSetting.ai_toxicity_flag_automatically = true

      classification.classify!(post)

      expect(ReviewableFlaggedPost.where(target: post).count).to eq(1)
      expect(post.reload.hidden?).to eq(true)
    end

    it "doesn't flags the message if the model decides we shouldn't" do
      SiteSetting.ai_toxicity_flag_automatically = false

      classification.classify!(post)

      expect(ReviewableFlaggedPost.where(target: post).count).to be_zero
    end
  end
end
