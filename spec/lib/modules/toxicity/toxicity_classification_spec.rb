# frozen_string_literal: true

require_relative "../../../support/toxicity_inference_stubs"

describe DiscourseAi::Toxicity::ToxicityClassification do
  fab!(:target) { Fabricate(:post) }

  describe "#request" do
    it "returns the classification and the model used for it" do
      ToxicityInferenceStubs.stub_post_classification(target, toxic: false)

      result = subject.request(target)

      expect(result[SiteSetting.ai_toxicity_inference_service_api_model]).to eq(
        ToxicityInferenceStubs.civilized_response,
      )
    end
  end

  describe "#should_flag_based_on?" do
    before { SiteSetting.ai_toxicity_flag_automatically = true }

    let(:toxic_verdict) { { SiteSetting.ai_toxicity_inference_service_api_model => true } }

    it "returns false when toxicity flagging is disabled" do
      SiteSetting.ai_toxicity_flag_automatically = false

      should_flag = subject.should_flag_based_on?(toxic_verdict)

      expect(should_flag).to eq(false)
    end

    it "returns true if the response is toxic based on our thresholds" do
      should_flag = subject.should_flag_based_on?(toxic_verdict)

      expect(should_flag).to eq(true)
    end

    it "returns false if the response is civilized based on our thresholds" do
      civilized_verdict = { SiteSetting.ai_toxicity_inference_service_api_model => false }

      should_flag = subject.should_flag_based_on?(civilized_verdict)

      expect(should_flag).to eq(false)
    end
  end
end
