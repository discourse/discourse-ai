# frozen_string_literal: true

require "rails_helper"
require_relative "../../../../../support/toxicity_inference_stubs"

describe Jobs::ToxicityClassifyPost do
  describe "#execute" do
    before do
      SiteSetting.ai_toxicity_enabled = true
      SiteSetting.ai_toxicity_flag_automatically = true
      SiteSetting.ai_toxicity_inference_service_api_endpoint = "http://example.com"
    end

    fab!(:post)

    describe "scenarios where we return early without doing anything" do
      it "does nothing when ai_toxicity_enabled is disabled" do
        SiteSetting.ai_toxicity_enabled = false

        subject.execute({ post_id: post.id })

        expect(ReviewableAiPost.where(target: post).count).to be_zero
      end

      it "does nothing if there's no arg called post_id" do
        subject.execute({})

        expect(ReviewableAiPost.where(target: post).count).to be_zero
      end

      it "does nothing if no post match the given id" do
        subject.execute({ post_id: nil })

        expect(ReviewableAiPost.where(target: post).count).to be_zero
      end

      it "does nothing if the post content is blank" do
        post.update_columns(raw: "")

        subject.execute({ post_id: post.id })

        expect(ReviewableAiPost.where(target: post).count).to be_zero
      end
    end

    it "flags the post when classified as toxic" do
      ToxicityInferenceStubs.stub_post_classification(post, toxic: true)

      subject.execute({ post_id: post.id })

      expect(ReviewableAiPost.where(target: post).count).to eq(1)
    end
  end
end
