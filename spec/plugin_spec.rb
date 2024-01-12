# frozen_string_literal: true

require_relative "support/toxicity_inference_stubs"

describe Plugin::Instance do
  before { SiteSetting.discourse_ai_enabled = true }

  describe "on reviewable_transitioned_to event" do
    fab!(:post) { Fabricate(:post) }
    fab!(:admin) { Fabricate(:admin) }

    it "adjusts model accuracy" do
      ToxicityInferenceStubs.stub_post_classification(post, toxic: true)
      SiteSetting.ai_toxicity_flag_automatically = true
      classification = DiscourseAi::Toxicity::ToxicityClassification.new
      classificator = DiscourseAi::PostClassificator.new(classification)
      classificator.classify!(post)
      reviewable = ReviewableAiPost.find_by(target: post)

      reviewable.perform admin, :agree_and_keep
      accuracy = ModelAccuracy.find_by(classification_type: classification.type)

      expect(accuracy.flags_agreed).to eq(1)
    end
  end
end
