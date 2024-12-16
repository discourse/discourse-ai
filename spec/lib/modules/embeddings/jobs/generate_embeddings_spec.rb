# frozen_string_literal: true

RSpec.describe Jobs::GenerateEmbeddings do
  subject(:job) { described_class.new }

  describe "#execute" do
    before do
      SiteSetting.ai_embeddings_discourse_service_api_endpoint = "http://test.com"
      SiteSetting.ai_embeddings_enabled = true
    end

    fab!(:topic)
    fab!(:post) { Fabricate(:post, post_number: 1, topic: topic) }

    let(:vector_def) { DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation }
    let(:topics_schema) { DiscourseAi::Embeddings::Schema.for(Topic, vector_def: vector_def) }
    let(:posts_schema) { DiscourseAi::Embeddings::Schema.for(Post, vector_def: vector_def) }

    it "works for topics" do
      expected_embedding = [0.0038493] * vector_def.dimensions

      text = vector_def.prepare_target_text(topic)

      EmbeddingsGenerationStubs.discourse_service(vector_def.class.name, text, expected_embedding)

      job.execute(target_id: topic.id, target_type: "Topic")

      expect(topics_schema.find_by_embedding(expected_embedding).topic_id).to eq(topic.id)
    end

    it "works for posts" do
      expected_embedding = [0.0038493] * vector_def.dimensions

      text = vector_def.prepare_target_text(post)
      EmbeddingsGenerationStubs.discourse_service(vector_def.class.name, text, expected_embedding)

      job.execute(target_id: post.id, target_type: "Post")

      expect(posts_schema.find_by_embedding(expected_embedding).post_id).to eq(post.id)
    end
  end
end
