# frozen_string_literal: true

require "rails_helper"

describe DiscourseAi::Nsfw::EntryPoint do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

  describe "registering event callbacks" do
    fab!(:image_upload) { Fabricate(:upload) }
    let(:raw_with_upload) { "A public post with an image.\n![](#{image_upload.short_path})" }

    before { SiteSetting.ai_nsfw_detection_enabled = true }

    context "when creating a post" do
      let(:creator) do
        PostCreator.new(user, raw: raw_with_upload, title: "this is my new topic title")
      end

      it "queues a job on create if sentiment analysis is enabled" do
        expect { creator.create }.to change(Jobs::EvaluatePostUploads.jobs, :size).by(1)
      end

      it "does nothing if sentiment analysis is disabled" do
        SiteSetting.ai_nsfw_detection_enabled = false

        expect { creator.create }.not_to change(Jobs::EvaluatePostUploads.jobs, :size)
      end

      it "does nothing if the post has no uploads" do
        creator_2 =
          PostCreator.new(user, raw: "this is a test", title: "this is my new topic title")

        expect { creator_2.create }.not_to change(Jobs::EvaluatePostUploads.jobs, :size)
      end
    end

    context "when editing a post" do
      fab!(:post) { Fabricate(:post, user: user) }
      let(:revisor) { PostRevisor.new(post) }

      it "queues a job on update if sentiment analysis is enabled" do
        expect { revisor.revise!(user, raw: raw_with_upload) }.to change(
          Jobs::EvaluatePostUploads.jobs,
          :size,
        ).by(1)
      end

      it "does nothing if sentiment analysis is disabled" do
        SiteSetting.ai_nsfw_detection_enabled = false

        expect { revisor.revise!(user, raw: raw_with_upload) }.not_to change(
          Jobs::EvaluatePostUploads.jobs,
          :size,
        )
      end

      it "does nothing if the new raw has no uploads" do
        expect { revisor.revise!(user, raw: "this is a test") }.not_to change(
          Jobs::EvaluatePostUploads.jobs,
          :size,
        )
      end
    end
  end
end
