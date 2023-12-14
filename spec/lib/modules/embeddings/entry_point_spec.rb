# frozen_string_literal: true

require "rails_helper"

describe DiscourseAi::Embeddings::EntryPoint do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

  describe "registering event callbacks" do
    context "when creating a topic" do
      let(:creator) do
        PostCreator.new(
          user,
          raw: "this is the new content for my topic",
          title: "this is my new topic title",
        )
      end

      it "queues a job on create if embeddings is enabled" do
        SiteSetting.ai_embeddings_enabled = true

        expect { creator.create }.to change(Jobs::GenerateEmbeddings.jobs, :size).by(1)
      end

      it "does nothing if sentiment analysis is disabled" do
        SiteSetting.ai_embeddings_enabled = false

        expect { creator.create }.not_to change(Jobs::GenerateEmbeddings.jobs, :size)
      end
    end
  end
end
