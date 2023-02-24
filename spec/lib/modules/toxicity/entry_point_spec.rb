# frozen_string_literal: true

require "rails_helper"

describe DiscourseAI::Toxicity::EntryPoint do
  fab!(:user) { Fabricate(:user) }

  describe "registering event callbacks" do
    before { SiteSetting.ai_toxicity_enabled = true }

    context "when creating a post" do
      let(:creator) do
        PostCreator.new(
          user,
          raw: "this is the new content for my topic",
          title: "this is my new topic title",
        )
      end

      it "queues a job on post creation" do
        SiteSetting.ai_toxicity_enabled = true

        expect { creator.create }.to change(Jobs::ToxicityClassifyPost.jobs, :size).by(1)
      end
    end

    context "when editing a post" do
      fab!(:post) { Fabricate(:post, user: user) }
      let(:revisor) { PostRevisor.new(post) }

      it "queues a job on post update" do
        expect { revisor.revise!(user, raw: "This is my new test") }.to change(
          Jobs::ToxicityClassifyPost.jobs,
          :size,
        ).by(1)
      end
    end

    context "when creating a chat message" do
      let(:public_chat_channel) { Fabricate(:chat_channel) }
      let(:creator) do
        Chat::ChatMessageCreator.new(
          chat_channel: public_chat_channel,
          user: user,
          content: "This is my new test",
        )
      end

      it "queues a job when creating a chat message" do
        expect { creator.create }.to change(Jobs::ToxicityClassifyChatMessage.jobs, :size).by(1)
      end
    end

    context "when editing a chat message" do
      let(:chat_message) { Fabricate(:chat_message) }
      let(:updater) do
        Chat::ChatMessageUpdater.new(
          guardian: Guardian.new(chat_message.user),
          chat_message: chat_message,
          new_content: "This is my updated message",
        )
      end

      it "queues a job on chat message update" do
        expect { updater.update }.to change(Jobs::ToxicityClassifyChatMessage.jobs, :size).by(1)
      end
    end
  end
end
