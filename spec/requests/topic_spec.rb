# frozen_string_literal: true

require "rails_helper"

describe ::TopicsController do
  fab!(:topic) { Fabricate(:topic) }
  fab!(:topic1) { Fabricate(:topic) }
  fab!(:topic2) { Fabricate(:topic) }
  fab!(:topic3) { Fabricate(:topic) }
  fab!(:user) { Fabricate(:admin) }

  before do
    Discourse.cache.clear
    SiteSetting.ai_embeddings_semantic_related_topics_enabled = true
    SiteSetting.ai_embeddings_semantic_related_topics = 2
  end

  after { Discourse.cache.clear }

  context "when a user is logged on" do
    it "includes related topics in payload when configured" do
      DiscourseAi::Embeddings::SemanticRelated.expects(:symmetric_semantic_search).returns(
        [topic1.id, topic2.id, topic3.id],
      )

      get("#{topic.relative_url}.json")
      expect(response.status).to eq(200)
      json = response.parsed_body

      expect(json["suggested_topics"].length).to eq(0)
      expect(json["related_topics"].length).to eq(2)

      sign_in(user)

      get("#{topic.relative_url}.json")
      json = response.parsed_body

      expect(json["suggested_topics"].length).to eq(0)
      expect(json["related_topics"].length).to eq(2)
    end
  end
end
