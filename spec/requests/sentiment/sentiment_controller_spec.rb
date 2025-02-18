# frozen_string_literal: true

RSpec.describe DiscourseAi::Sentiment::SentimentController do
  describe "#posts" do
    fab!(:user)
    fab!(:category)
    fab!(:post) { Fabricate(:post, user: user) }
    fab!(:embedding_definition)

    # before do
    # SiteSetting.ai_embeddings_enabled = false
    # SiteSetting.ai_embeddings_selected_model = ""
    # sign_in(user)
    # end

    it "returns a posts based on params" do
      get "/discourse-ai/sentiment/posts.json",
          params: {
            group_by: "category",
            group_value: category.name,
            start_date: 1.month.ago.to_s,
            end_date: 0.days.ago.to_s,
            threshold: 0.6,
          }

      pp response.inspect
      expect(response).to be_successful
    end
  end
end
