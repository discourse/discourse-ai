# frozen_string_literal: true

require_relative "../../../support/sentiment_inference_stubs"

RSpec.describe DiscourseAi::Sentiment::EntryPoint do
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

  describe "custom reports" do
    before { SiteSetting.ai_sentiment_inference_service_api_endpoint = "http://test.com" }

    fab!(:pm) { Fabricate(:private_message_post) }

    fab!(:post_1) { Fabricate(:post) }
    fab!(:post_2) { Fabricate(:post) }

    describe "overall_sentiment report" do
      let(:positive_classification) { { negative: 2, neutral: 30, positive: 70 } }
      let(:negative_classification) { { negative: 60, neutral: 2, positive: 10 } }

      def sentiment_classification(post, classification)
        Fabricate(:sentiment_classification, target: post, classification: classification)
      end

      it "calculate averages using only public posts" do
        sentiment_classification(post_1, positive_classification)
        sentiment_classification(post_2, negative_classification)
        sentiment_classification(pm, positive_classification)

        expected_positive =
          (positive_classification[:positive] + negative_classification[:positive]) / 2
        expected_negative =
          -(positive_classification[:negative] + negative_classification[:negative]) / 2

        report = Report.find("overall_sentiment")
        positive_data_point = report.data[0][:data].first[:y].to_i
        negative_data_point = report.data[1][:data].first[:y].to_i

        expect(positive_data_point).to eq(expected_positive)
        expect(negative_data_point).to eq(expected_negative)
      end
    end

    describe "post_emotion report" do
      let(:emotion_1) do
        { sadness: 49, surprise: 23, neutral: 6, fear: 34, anger: 87, joy: 22, disgust: 70 }
      end
      let(:emotion_2) do
        { sadness: 19, surprise: 63, neutral: 45, fear: 44, anger: 27, joy: 62, disgust: 30 }
      end
      let(:model_used) { "emotion" }

      def emotion_classification(post, classification)
        Fabricate(
          :sentiment_classification,
          target: post,
          model_used: model_used,
          classification: classification,
        )
      end

      it "calculate averages using only public posts" do
        post_1.user.update!(trust_level: TrustLevel[0])
        post_2.user.update!(trust_level: TrustLevel[3])
        pm.user.update!(trust_level: TrustLevel[0])

        emotion_classification(post_1, emotion_1)
        emotion_classification(post_2, emotion_2)
        emotion_classification(pm, emotion_2)

        report = Report.find("post_emotion")
        tl_01_point = report.data[0][:data].first
        tl_234_point = report.data[1][:data].first

        expect(tl_01_point[:y]).to eq(emotion_1[tl_01_point[:x].downcase.to_sym])
        expect(tl_234_point[:y]).to eq(emotion_2[tl_234_point[:x].downcase.to_sym])
      end

      it "doesn't try to divide by zero if there are no data in a TL group" do
        post_1.user.update!(trust_level: TrustLevel[3])
        post_2.user.update!(trust_level: TrustLevel[3])

        emotion_classification(post_1, emotion_1)
        emotion_classification(post_2, emotion_2)

        report = Report.find("post_emotion")
        tl_01_point = report.data[0][:data].first

        expect(tl_01_point[:y]).to be_zero
      end
    end
  end
end
