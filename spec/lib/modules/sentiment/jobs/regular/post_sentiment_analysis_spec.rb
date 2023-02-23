# frozen_string_literal: true

require "rails_helper"
require_relative "../../../../../support/sentiment_inference_stubs"

describe Jobs::PostSentimentAnalysis do
  describe "#execute" do
    let(:post) { Fabricate(:post) }

    before do
      SiteSetting.ai_sentiment_enabled = true
      SiteSetting.ai_sentiment_inference_service_api_endpoint = "http://test.com"
    end

    describe "scenarios where we return early without doing anything" do
      it "does nothing when ai_sentiment_enabled is disabled" do
        SiteSetting.ai_sentiment_enabled = false

        subject.execute({ post_id: post.id })

        expect(PostCustomField.where(post: post).count).to be_zero
      end

      it "does nothing if there's no arg called post_id" do
        subject.execute({})

        expect(PostCustomField.where(post: post).count).to be_zero
      end

      it "does nothing if no post match the given id" do
        subject.execute({ post_id: nil })

        expect(PostCustomField.where(post: post).count).to be_zero
      end

      it "does nothing if the post content is blank" do
        post.update_columns(raw: "")

        subject.execute({ post_id: post.id })

        expect(PostCustomField.where(post: post).count).to be_zero
      end
    end

    it "succesfully classifies the post" do
      expected_analysis = SiteSetting.ai_sentiment_models.split("|").length
      SentimentInferenceStubs.stub_classification(post)

      subject.execute({ post_id: post.id })

      expect(PostCustomField.where(post: post).count).to eq(expected_analysis)
    end
  end
end
