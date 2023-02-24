# frozen_string_literal: true

require "rails_helper"
require_relative "../../../support/toxicity_inference_stubs"

describe DiscourseAI::Toxicity::PostClassifier do
  before { SiteSetting.ai_toxicity_flag_automatically = true }

  fab!(:post) { Fabricate(:post) }

  describe "#classify!" do
    it "creates a reviewable when the post is classified as toxic" do
      ToxicityInferenceStubs.stub_post_classification(post, toxic: true)

      subject.classify!(post)

      expect(ReviewableFlaggedPost.where(target: post).count).to eq(1)
    end

    it "doesn't create a reviewable if the post is not classified as toxic" do
      ToxicityInferenceStubs.stub_post_classification(post, toxic: false)

      subject.classify!(post)

      expect(ReviewableFlaggedPost.where(target: post).count).to be_zero
    end

    it "doesn't create a reviewable if flagging is disabled" do
      SiteSetting.ai_toxicity_flag_automatically = false
      ToxicityInferenceStubs.stub_post_classification(post, toxic: true)

      subject.classify!(post)

      expect(ReviewableFlaggedPost.where(target: post).count).to be_zero
    end

    it "stores the classification in a custom field" do
      ToxicityInferenceStubs.stub_post_classification(post, toxic: false)

      subject.classify!(post)
      custom_field = PostCustomField.find_by(post: post, name: "toxicity")

      expect(custom_field.value).to eq(
        {
          classification: ToxicityInferenceStubs.civilized_response,
          model: SiteSetting.ai_toxicity_inference_service_api_model,
        }.to_json,
      )
    end
  end
end
