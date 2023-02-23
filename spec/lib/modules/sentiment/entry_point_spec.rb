# frozen_string_literal: true

require "rails_helper"

describe DiscourseAI::Sentiment::EntryPoint do
  fab!(:user) { Fabricate(:user) }

  describe "registering event callbacks" do
    context "when creating a post" do
      let(:creator) do
        PostCreator.new(
          user,
          raw: "this is the new content for my topic",
          title: "this is my new topic title",
        )
      end

      it "queues a job on create if sentiment analysis is enabled" do
        SiteSetting.ai_sentiment_enabled = true

        expect { creator.create }.to change(Jobs::PostSentimentAnalysis.jobs, :size).by(1)
      end

      it "does nothing if sentiment analysis is disabled" do
        SiteSetting.ai_sentiment_enabled = false

        expect { creator.create }.not_to change(Jobs::PostSentimentAnalysis.jobs, :size)
      end
    end

    context "when editing a post" do
      fab!(:post) { Fabricate(:post, user: user) }
      let(:revisor) { PostRevisor.new(post) }

      it "queues a job on update if sentiment analysis is enabled" do
        SiteSetting.ai_sentiment_enabled = true

        expect { revisor.revise!(user, raw: "This is my new test") }.to change(
          Jobs::PostSentimentAnalysis.jobs,
          :size,
        ).by(1)
      end

      it "does nothing if sentiment analysis is disabled" do
        SiteSetting.ai_sentiment_enabled = false

        expect { revisor.revise!(user, raw: "This is my new test") }.not_to change(
          Jobs::PostSentimentAnalysis.jobs,
          :size,
        )
      end
    end
  end
end
