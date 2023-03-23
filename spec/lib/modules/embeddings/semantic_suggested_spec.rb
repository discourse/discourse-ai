# frozen_string_literal: true

require "rails_helper"

describe DiscourseAi::Embeddings::SemanticSuggested do
  fab!(:target) { Fabricate(:topic) }
  fab!(:normal_topic_1) { Fabricate(:topic) }
  fab!(:normal_topic_2) { Fabricate(:topic) }
  fab!(:normal_topic_3) { Fabricate(:topic) }
  fab!(:unlisted_topic) { Fabricate(:topic, visible: false) }
  fab!(:private_topic) { Fabricate(:private_message_topic) }
  fab!(:secured_category) { Fabricate(:category, read_restricted: true) }
  fab!(:secured_category_topic) { Fabricate(:topic, category: secured_category) }

  before { SiteSetting.ai_embeddings_semantic_suggested_topics_anons_enabled = true }

  describe "#build_suggested_topics" do
    before do
      Discourse.cache.clear
      described_class.stubs(:search_suggestions).returns(
        Topic.unscoped.order(id: :desc).limit(10).pluck(:id),
      )
    end

    after { Discourse.cache.clear }

    it "returns the suggested topics without non public topics" do
      suggested = described_class.build_suggested_topics(target, {}, TopicQuery.new(nil))
      suggested_results = suggested[:result]
      expect(suggested_results).to include(normal_topic_1)
      expect(suggested_results).to include(normal_topic_2)
      expect(suggested_results).to include(normal_topic_3)
      expect(suggested_results).to_not include(unlisted_topic)
      expect(suggested_results).to_not include(private_topic)
      expect(suggested_results).to_not include(secured_category_topic)
    end
  end
end
