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

  before do
    SiteSetting.ai_embeddings_model = "bge-large-en"
    SiteSetting.ai_embeddings_semantic_related_topics_enabled = true
  end

  describe "#related_topic_ids_for" do
    context "when embeddings do not exist" do
      let(:topic) do
        post = Fabricate(:post)
        topic = post.topic
        described_class.clear_cache_for(target)
        topic
      end

      let(:vector_rep) do
        strategy = DiscourseAi::Embeddings::Strategies::Truncation.new

        DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(strategy)
      end

      it "properly generates embeddings if missing" do
        SiteSetting.ai_embeddings_enabled = true
        SiteSetting.ai_embeddings_discourse_service_api_endpoint = "http://test.com"
        Jobs.run_immediately!

        embedding = Array.new(1024) { 1 }

        WebMock.stub_request(
          :post,
          "#{SiteSetting.ai_embeddings_discourse_service_api_endpoint}/api/v1/classify",
        ).to_return(status: 200, body: JSON.dump(embedding))

        # miss first
        ids = semantic_related.related_topic_ids_for(topic)

        # clear cache so we lookup
        described_class.clear_cache_for(topic)

        # hit cause we queued generation
        ids = semantic_related.related_topic_ids_for(topic)

        # at this point though the only embedding is ourselves
        expect(ids).to eq([topic.id])
      end

      it "queues job only once per 15 minutes" do
        results = nil

        expect_enqueued_with(
          job: :generate_embeddings,
          args: {
            target_id: topic.id,
            target_type: "Topic",
          },
        ) { results = semantic_related.related_topic_ids_for(topic) }

        expect(results).to eq([])

        expect_not_enqueued_with(
          job: :generate_embeddings,
          args: {
            target_id: topic.id,
            target_type: "Topic",
          },
        ) { results = semantic_related.related_topic_ids_for(topic) }

        expect(results).to eq([])
      end
    end
  end
end
