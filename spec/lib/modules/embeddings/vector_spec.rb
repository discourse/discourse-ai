# frozen_string_literal: true

RSpec.describe DiscourseAi::Embeddings::Vector do
  shared_examples "generates and store embeddings using a vector definition" do
    subject(:vector) { described_class.new(vdef) }

    let(:expected_embedding_1) { [0.0038493] * vdef.dimensions }
    let(:expected_embedding_2) { [0.0037684] * vdef.dimensions }

    let(:topics_schema) { DiscourseAi::Embeddings::Schema.for(Topic, vector_def: vdef) }
    let(:posts_schema) { DiscourseAi::Embeddings::Schema.for(Post, vector_def: vdef) }

    fab!(:topic)
    fab!(:post) { Fabricate(:post, post_number: 1, topic: topic) }
    fab!(:post2) { Fabricate(:post, post_number: 2, topic: topic) }

    describe "#vector_from" do
      it "creates a vector from a given string" do
        text = "This is a piece of text"
        stub_vector_mapping(text, expected_embedding_1)

        expect(vector.vector_from(text)).to eq(expected_embedding_1)
      end
    end

    describe "#generate_representation_from" do
      it "creates a vector from a topic and stores it in the database" do
        text = vdef.prepare_target_text(topic)
        stub_vector_mapping(text, expected_embedding_1)

        vector.generate_representation_from(topic)

        expect(topics_schema.find_by_embedding(expected_embedding_1).topic_id).to eq(topic.id)
      end

      it "creates a vector from a post and stores it in the database" do
        text = vdef.prepare_target_text(post2)
        stub_vector_mapping(text, expected_embedding_1)

        vector.generate_representation_from(post)

        expect(posts_schema.find_by_embedding(expected_embedding_1).post_id).to eq(post.id)
      end
    end

    describe "#gen_bulk_reprensentations" do
      fab!(:topic_2) { Fabricate(:topic) }
      fab!(:post_2_1) { Fabricate(:post, post_number: 1, topic: topic_2) }
      fab!(:post_2_2) { Fabricate(:post, post_number: 2, topic: topic_2) }

      it "creates a vector for each object in the relation" do
        text = vdef.prepare_target_text(topic)

        text2 = vdef.prepare_target_text(topic_2)

        stub_vector_mapping(text, expected_embedding_1)
        stub_vector_mapping(text2, expected_embedding_2)

        vector.gen_bulk_reprensentations(Topic.where(id: [topic.id, topic_2.id]))

        expect(topics_schema.find_by_embedding(expected_embedding_1).topic_id).to eq(topic.id)
      end

      it "does nothing if passed record has no content" do
        expect { vector.gen_bulk_reprensentations([Topic.new]) }.not_to raise_error
      end

      it "doesn't ask for a new embedding if digest is the same" do
        text = vdef.prepare_target_text(topic)
        stub_vector_mapping(text, expected_embedding_1)

        original_vector_gen = Time.zone.parse("2021-06-04 10:00")

        freeze_time(original_vector_gen) do
          vector.gen_bulk_reprensentations(Topic.where(id: [topic.id]))
        end
        # check vector exists
        expect(topics_schema.find_by_embedding(expected_embedding_1).topic_id).to eq(topic.id)

        vector.gen_bulk_reprensentations(Topic.where(id: [topic.id]))

        expect(topics_schema.find_by_target(topic).updated_at).to eq_time(original_vector_gen)
      end
    end
  end

  context "with text-embedding-ada-002" do
    let(:vdef) { DiscourseAi::Embeddings::VectorRepresentations::TextEmbeddingAda002.new }

    def stub_vector_mapping(text, expected_embedding)
      EmbeddingsGenerationStubs.openai_service(vdef.class.name, text, expected_embedding)
    end

    it_behaves_like "generates and store embeddings using a vector definition"
  end

  context "with all all-mpnet-base-v2" do
    let(:vdef) { DiscourseAi::Embeddings::VectorRepresentations::AllMpnetBaseV2.new }

    before { SiteSetting.ai_embeddings_discourse_service_api_endpoint = "http://test.com" }

    def stub_vector_mapping(text, expected_embedding)
      EmbeddingsGenerationStubs.discourse_service(vdef.class.name, text, expected_embedding)
    end

    it_behaves_like "generates and store embeddings using a vector definition"
  end

  context "with gemini" do
    let(:vdef) { DiscourseAi::Embeddings::VectorRepresentations::Gemini.new }
    let(:api_key) { "test-123" }

    before { SiteSetting.ai_gemini_api_key = api_key }

    def stub_vector_mapping(text, expected_embedding)
      EmbeddingsGenerationStubs.gemini_service(api_key, text, expected_embedding)
    end

    it_behaves_like "generates and store embeddings using a vector definition"
  end

  context "with multilingual-e5-large" do
    let(:vdef) { DiscourseAi::Embeddings::VectorRepresentations::MultilingualE5Large.new }

    before { SiteSetting.ai_embeddings_discourse_service_api_endpoint = "http://test.com" }

    def stub_vector_mapping(text, expected_embedding)
      EmbeddingsGenerationStubs.discourse_service(vdef.class.name, text, expected_embedding)
    end

    it_behaves_like "generates and store embeddings using a vector definition"
  end

  context "with text-embedding-3-large" do
    let(:vdef) { DiscourseAi::Embeddings::VectorRepresentations::TextEmbedding3Large.new }

    def stub_vector_mapping(text, expected_embedding)
      EmbeddingsGenerationStubs.openai_service(
        vdef.class.name,
        text,
        expected_embedding,
        extra_args: {
          dimensions: 2000,
        },
      )
    end

    it_behaves_like "generates and store embeddings using a vector definition"
  end

  context "with text-embedding-3-small" do
    let(:vdef) { DiscourseAi::Embeddings::VectorRepresentations::TextEmbedding3Small.new }

    def stub_vector_mapping(text, expected_embedding)
      EmbeddingsGenerationStubs.openai_service(vdef.class.name, text, expected_embedding)
    end

    it_behaves_like "generates and store embeddings using a vector definition"
  end
end
