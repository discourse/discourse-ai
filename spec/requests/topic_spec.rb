# frozen_string_literal: true

require "rails_helper"

describe ::TopicsController do
  fab!(:topic) { Fabricate(:topic) }
  fab!(:topic1) { Fabricate(:topic) }
  fab!(:topic2) { Fabricate(:topic) }
  fab!(:user) { Fabricate(:admin) }

  before do
    Discourse.cache.clear
    SiteSetting.ai_embeddings_semantic_suggested_topics_enabled = true
  end

  after { Discourse.cache.clear }

  context "when a user is logged on" do
    it "includes related topics in payload when configured" do
      DiscourseAi::Embeddings::SemanticSuggested.stubs(:search_suggestions).returns([topic2.id])
      sign_in(user)

      get("#{topic.relative_url}.json")
      json = response.parsed_body

      expect(json["suggested_topics"].length).to eq(0)
      expect(json["related_topics"].length).to be > 0
    end
  end
end
