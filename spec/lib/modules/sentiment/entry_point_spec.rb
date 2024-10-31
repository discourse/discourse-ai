# frozen_string_literal: true

require_relative "../../../support/sentiment_inference_stubs"

RSpec.describe DiscourseAi::Sentiment::EntryPoint do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

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
    before do
      SiteSetting.ai_sentiment_model_configs =
        "[{\"model_name\":\"SamLowe/roberta-base-go_emotions\",\"endpoint\":\"http://samlowe-emotion.com\",\"api_key\":\"123\"},{\"model_name\":\"j-hartmann/emotion-english-distilroberta-base\",\"endpoint\":\"http://jhartmann-emotion.com\",\"api_key\":\"123\"},{\"model_name\":\"cardiffnlp/twitter-roberta-base-sentiment-latest\",\"endpoint\":\"http://cardiffnlp-sentiment.com\",\"api_key\":\"123\"}]"
    end

    fab!(:pm) { Fabricate(:private_message_post) }

    fab!(:post_1) { Fabricate(:post) }
    fab!(:post_2) { Fabricate(:post) }

    describe "overall_sentiment report" do
      let(:positive_classification) { { negative: 2, neutral: 30, positive: 70 } }
      let(:negative_classification) { { negative: 65, neutral: 2, positive: 10 } }

      def sentiment_classification(post, classification)
        Fabricate(:sentiment_classification, target: post, classification: classification)
      end

      it "calculate averages using only public posts" do
        sentiment_classification(post_1, positive_classification)
        sentiment_classification(post_2, negative_classification)
        sentiment_classification(pm, positive_classification)

        report = Report.find("overall_sentiment")
        positive_data_point = report.data[0][:data].first[:y].to_i
        negative_data_point = report.data[1][:data].first[:y].to_i

        expect(positive_data_point).to eq(1)
        expect(negative_data_point).to eq(-1)
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

      def strip_emoji_and_downcase(str)
        stripped_str = str.gsub(/[^\p{L}\p{N}]+/, "") # remove any non-alphanumeric characters
        stripped_str.downcase
      end

      it "calculate averages using only public posts" do
        threshold = 30

        emotion_classification(post_1, emotion_1)
        emotion_classification(post_2, emotion_2)
        emotion_classification(pm, emotion_2)

        report = Report.find("post_emotion")

        data_point = report.data

        data_point.each do |point|
          emotion = strip_emoji_and_downcase(point[:label])
          expected =
            (emotion_1[emotion.to_sym] > threshold ? 1 : 0) +
              (emotion_2[emotion.to_sym] > threshold ? 1 : 0)
          expect(point[:data][0][:y]).to eq(expected)
        end
      end
    end
  end
end
