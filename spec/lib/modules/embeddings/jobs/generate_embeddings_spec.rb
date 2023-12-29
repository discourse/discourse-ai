# frozen_string_literal: true

RSpec.describe Jobs::GenerateEmbeddings do
  subject(:job) { described_class.new }

  describe "#execute" do
    before do
      SiteSetting.ai_embeddings_discourse_service_api_endpoint = "http://test.com"
      SiteSetting.ai_embeddings_enabled = true
      SiteSetting.ai_embeddings_model = "all-mpnet-base-v2"
    end

    fab!(:topic) { Fabricate(:topic) }
    fab!(:post) { Fabricate(:post, post_number: 1, topic: topic) }

    let(:truncation) { DiscourseAi::Embeddings::Strategies::Truncation.new }
    let(:vector_rep) do
      DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(truncation)
    end

    it "works for topics" do
      expected_embedding = [0.0038493] * vector_rep.dimensions

      text =
        truncation.prepare_text_from(
          topic,
          vector_rep.tokenizer,
          vector_rep.max_sequence_length - 2,
        )
      EmbeddingsGenerationStubs.discourse_service(vector_rep.name, text, expected_embedding)

      job.execute(target_id: topic.id, target_type: "Topic")

      expect(vector_rep.topic_id_from_representation(expected_embedding)).to eq(topic.id)
    end

    it "works for posts" do
      expected_embedding = [0.0038493] * vector_rep.dimensions

      text =
        truncation.prepare_text_from(post, vector_rep.tokenizer, vector_rep.max_sequence_length - 2)
      EmbeddingsGenerationStubs.discourse_service(vector_rep.name, text, expected_embedding)

      job.execute(target_id: post.id, target_type: "Post")

      expect(vector_rep.post_id_from_representation(expected_embedding)).to eq(post.id)
    end
  end
end
