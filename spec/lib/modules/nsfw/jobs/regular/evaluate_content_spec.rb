# frozen_string_literal: true

require "rails_helper"
require_relative "../../../../../support/nsfw_inference_stubs"

describe Jobs::EvaluateContent do
  fab!(:image) { Fabricate(:s3_image_upload) }

  describe "#execute" do
    before { SiteSetting.ai_nsfw_inference_service_api_endpoint = "http://test.com" }

    context "when we conclude content is NSFW" do
      before { NSFWInferenceStubs.positive(image) }

      it "deletes the upload" do
        subject.execute(upload_id: image.id)

        expect { image.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when we conclude content is not NSFW" do
      before { NSFWInferenceStubs.negative(image) }

      it "does nothing" do
        subject.execute(upload_id: image.id)

        expect(image.reload).to be_present
      end
    end
  end
end
