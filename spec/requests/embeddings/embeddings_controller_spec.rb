# frozen_string_literal: true

describe DiscourseAi::Embeddings::EmbeddingsController do
  context "when performing a topic search" do
    before do
      SiteSetting.min_search_term_length = 3
      SiteSetting.ai_embeddings_model = "text-embedding-3-small"
      DiscourseAi::Embeddings::SemanticSearch.clear_cache_for("test")
      SearchIndexer.enable
    end

    fab!(:category)
    fab!(:subcategory) { Fabricate(:category, parent_category_id: category.id) }

    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic: topic) }

    fab!(:topic_in_subcategory) { Fabricate(:topic, category: subcategory) }
    fab!(:post_in_subcategory) { Fabricate(:post, topic: topic_in_subcategory) }

    def index(topic)
      strategy = DiscourseAi::Embeddings::Strategies::Truncation.new
      vector_rep =
        DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(strategy)

      stub_request(:post, "https://api.openai.com/v1/embeddings").to_return(
        status: 200,
        body: JSON.dump({ data: [{ embedding: [0.1] * 1536 }] }),
      )

      vector_rep.generate_representation_from(topic)
    end

    def stub_embedding(query)
      embedding = [0.049382] * 1536
      EmbeddingsGenerationStubs.openai_service(SiteSetting.ai_embeddings_model, query, embedding)
    end

    it "returns results correctly when performing a non Hyde search" do
      index(topic)
      index(topic_in_subcategory)

      query = "test"
      stub_embedding(query)

      get "/discourse-ai/embeddings/semantic-search.json?q=#{query}&hyde=false"

      expect(response.status).to eq(200)
      expect(response.parsed_body["topics"].map { |t| t["id"] }).to contain_exactly(
        topic.id,
        topic_in_subcategory.id,
      )
    end

    it "is able to filter to a specific category (including sub categories)" do
      index(topic)
      index(topic_in_subcategory)

      query = "test category:#{category.slug}"
      stub_embedding("test")

      get "/discourse-ai/embeddings/semantic-search.json?q=#{query}&hyde=false"

      expect(response.status).to eq(200)
      expect(response.parsed_body["topics"].map { |t| t["id"] }).to eq([topic_in_subcategory.id])
    end
  end
end
