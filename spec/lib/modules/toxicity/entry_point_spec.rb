# frozen_string_literal: true

describe DiscourseAi::Toxicity::EntryPoint do
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
      fab!(:public_chat_channel) { Fabricate(:chat_channel) }

      it "queues a job when creating a chat message" do
        expect {
          Fabricate(
            :chat_message,
            chat_channel: public_chat_channel,
            user: user,
            message: "This is my new test",
            use_service: true,
          )
        }.to change(Jobs::ToxicityClassifyChatMessage.jobs, :size).by(1)
      end
    end

    context "when editing a chat message" do
      # This fabricator trigger events because it uses the UpdateMessage service.
      # Using let makes the test fail.
      fab!(:chat_message) { Fabricate(:chat_message) }
      let(:updater) do
        Chat::UpdateMessage.call(
          guardian: Guardian.new(chat_message.user),
          message_id: chat_message.id,
          message: "This is my updated message",
        )
      end

      it "queues a job on chat message update" do
        expect { updater.update }.to change(Jobs::ToxicityClassifyChatMessage.jobs, :size).by(1)
      end
    end
  end
end
