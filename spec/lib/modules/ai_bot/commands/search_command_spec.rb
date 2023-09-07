#frozen_string_literal: true

require_relative "../../../../support/openai_completions_inference_stubs"
require_relative "../../../../support/embeddings_generation_stubs"

RSpec.describe DiscourseAi::AiBot::Commands::SearchCommand do
  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }

  before { SearchIndexer.enable }
  after { SearchIndexer.disable }

  describe "#process" do
    it "can handle no results" do
      post1 = Fabricate(:post)
      search = described_class.new(bot_user: bot_user, post: post1, args: nil)

      results = search.process(query: "order:fake ABDDCDCEDGDG")

      expect(results[:args]).to eq({ query: "order:fake ABDDCDCEDGDG" })
      expect(results[:rows]).to eq([])
    end

    describe "semantic search" do
      let (:query) {
        "this is an expanded search"
      }
      after { DiscourseAi::Embeddings::SemanticSearch.clear_cache_for(query) }

      it "supports semantic search when enabled" do
        SiteSetting.ai_embeddings_semantic_search_enabled = true
        SiteSetting.ai_embeddings_discourse_service_api_endpoint = "http://test.com"

        WebMock.stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: JSON.dump(OpenAiCompletionsInferenceStubs.response(query)),
        )

        hyde_embedding = [0.049382, 0.9999]
        EmbeddingsGenerationStubs.discourse_service(
          SiteSetting.ai_embeddings_model,
          query,
          hyde_embedding,
        )

        post1 = Fabricate(:post)
        search = described_class.new(bot_user: bot_user, post: post1, args: nil)

        DiscourseAi::Embeddings::VectorRepresentations::AllMpnetBaseV2
          .any_instance
          .expects(:asymmetric_topics_similarity_search)
          .returns([post1.topic_id])

        results = search.process(search_query: "hello world, sam")

        expect(results[:args]).to eq({ search_query: "hello world, sam" })
        expect(results[:rows].length).to eq(1)
      end
    end

    it "supports subfolder properly" do
      Discourse.stubs(:base_path).returns("/subfolder")

      post1 = Fabricate(:post)

      search = described_class.new(bot_user: bot_user, post: post1, args: nil)

      results = search.process(limit: 1, user: post1.user.username)
      expect(results[:rows].to_s).to include("/subfolder" + post1.url)
    end

    it "can handle limits" do
      post1 = Fabricate(:post)
      _post2 = Fabricate(:post, user: post1.user)
      _post3 = Fabricate(:post, user: post1.user)

      # search has no built in support for limit: so handle it from the outside
      search = described_class.new(bot_user: bot_user, post: post1, args: nil)

      results = search.process(limit: 2, user: post1.user.username)

      expect(results[:column_names].length).to eq(4)
      expect(results[:rows].length).to eq(2)

      # just searching for everything
      results = search.process(order: "latest_topic")
      expect(results[:rows].length).to be > 1
    end
  end
end
