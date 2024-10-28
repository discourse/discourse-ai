# frozen_string_literal: true

require_relative "../support/toxicity_inference_stubs"

describe DiscourseAi::PostClassificator do
  fab!(:post)

  let(:model) { DiscourseAi::Toxicity::ToxicityClassification.new }
  let(:classification) { described_class.new(model) }

  before { SiteSetting.ai_toxicity_inference_service_api_endpoint = "http://example.com" }

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

      expect(ReviewableAiPost.where(target: post).count).to eq(1)
      expect(post.reload.hidden?).to eq(true)
    end

    it "doesn't flags the message if the model decides we shouldn't" do
      SiteSetting.ai_toxicity_flag_automatically = false

      classification.classify!(post)

      expect(ReviewableAiPost.where(target: post).count).to be_zero
    end

    it "includes the model accuracy in the payload" do
      SiteSetting.ai_toxicity_flag_automatically = true
      classification.classify!(post)

      reviewable = ReviewableAiPost.find_by(target: post)

      expect(
        reviewable.payload.dig("accuracies", SiteSetting.ai_toxicity_inference_service_api_model),
      ).to be_zero
    end
  end
end
