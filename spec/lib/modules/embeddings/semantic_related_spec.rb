# frozen_string_literal: true

describe DiscourseAi::Embeddings::SemanticRelated do
  subject(:semantic_related) { described_class.new }

  fab!(:target) { Fabricate(:topic) }
  fab!(:normal_topic_1) { Fabricate(:topic) }
  fab!(:normal_topic_2) { Fabricate(:topic) }
  fab!(:normal_topic_3) { Fabricate(:topic) }
  fab!(:unlisted_topic) { Fabricate(:topic, visible: false) }
  fab!(:private_topic) { Fabricate(:private_message_topic) }
  fab!(:secured_category) { Fabricate(:category, read_restricted: true) }
  fab!(:secured_category_topic) { Fabricate(:topic, category: secured_category) }
  fab!(:closed_topic) { Fabricate(:topic, closed: true) }

  before { SiteSetting.ai_embeddings_semantic_related_topics_enabled = true }

  describe "#related_topic_ids_for" do
    context "when embeddings do not exist" do
      let(:topic) { Fabricate(:topic).tap { described_class.clear_cache_for(target) } }

      it "queues job only once per 15 minutes" do
        results = nil

        expect_enqueued_with(job: :generate_embeddings, args: { topic_id: topic.id }) do
          results = semantic_related.related_topic_ids_for(topic)
        end

        expect(results).to eq([])

        expect_not_enqueued_with(job: :generate_embeddings, args: { topic_id: topic.id }) do
          results = semantic_related.related_topic_ids_for(topic)
        end

        expect(results).to eq([])
      end
    end
  end
end
