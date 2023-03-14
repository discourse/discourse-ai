# frozen_string_literal: true

require "rails_helper"
require_relative "../../../../../support/nsfw_inference_stubs"

describe Jobs::EvaluatePostUploads do
  describe "#execute" do
    before do
      SiteSetting.ai_nsfw_detection_enabled = true
      SiteSetting.ai_nsfw_inference_service_api_endpoint = "http://test.com"
    end

    fab!(:upload_1) { Fabricate(:s3_image_upload) }
    fab!(:post) { Fabricate(:post, uploads: [upload_1]) }

    describe "scenarios where we return early without doing anything" do
      before { NSFWInferenceStubs.positive(upload_1) }

      it "does nothing when ai_toxicity_enabled is disabled" do
        SiteSetting.ai_nsfw_detection_enabled = false

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

      it "does nothing if the post has no uploads" do
        post_no_uploads = Fabricate(:post)

        subject.execute({ post_id: post_no_uploads.id })

        expect(ReviewableAiPost.where(target: post_no_uploads).count).to be_zero
      end

      it "does nothing if the upload is not an image" do
        SiteSetting.authorized_extensions = "pdf"
        upload_1.update!(original_filename: "test.pdf", url: "test.pdf")

        subject.execute({ post_id: post.id })

        expect(ReviewableAiPost.where(target: post).count).to be_zero
      end
    end

    context "when the post has one upload" do
      context "when we conclude content is NSFW" do
        before { NSFWInferenceStubs.positive(upload_1) }

        it "flags and hides the post" do
          subject.execute({ post_id: post.id })

          expect(ReviewableAiPost.where(target: post).count).to eq(1)
          expect(post.reload.hidden?).to eq(true)
        end
      end

      context "when we conclude content is safe" do
        before { NSFWInferenceStubs.negative(upload_1) }

        it "does nothing" do
          subject.execute({ post_id: post.id })

          expect(ReviewableAiPost.where(target: post).count).to be_zero
        end
      end
    end
  end
end
