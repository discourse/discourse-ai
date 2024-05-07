#frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Tools::Search do
  before { SearchIndexer.enable }
  after { SearchIndexer.disable }

  before { SiteSetting.ai_openai_api_key = "asd" }

  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("open_ai:gpt-3.5-turbo") }
  let(:progress_blk) { Proc.new {} }

  fab!(:admin)
  fab!(:parent_category) { Fabricate(:category, name: "animals") }
  fab!(:category) { Fabricate(:category, parent_category: parent_category, name: "amazing-cat") }
  fab!(:tag_funny) { Fabricate(:tag, name: "funny") }
  fab!(:tag_sad) { Fabricate(:tag, name: "sad") }
  fab!(:tag_hidden) { Fabricate(:tag, name: "hidden") }
  fab!(:staff_tag_group) do
    tag_group = Fabricate.build(:tag_group, name: "Staff only", tag_names: ["hidden"])

    tag_group.permissions = [
      [Group::AUTO_GROUPS[:staff], TagGroupPermission.permission_types[:full]],
    ]
    tag_group.save!
    tag_group
  end
  fab!(:topic_with_tags) do
    Fabricate(:topic, category: category, tags: [tag_funny, tag_sad, tag_hidden])
  end

  before { SiteSetting.ai_bot_enabled = true }

  describe "#invoke" do
    it "can retrieve options from persona correctly" do
      persona_options = { "base_query" => "#funny" }

      search_post = Fabricate(:post, topic: topic_with_tags)

      _bot_post = Fabricate(:post)

      search =
        described_class.new(
          { order: "latest" },
          persona_options: persona_options,
          bot_user: bot_user,
          llm: llm,
          context: {
          },
        )

      results = search.invoke(&progress_blk)
      expect(results[:rows].length).to eq(1)

      search_post.topic.tags = []
      search_post.topic.save!

      # no longer has the tag funny
      results = search.invoke(&progress_blk)
      expect(results[:rows].length).to eq(0)
    end

    it "can handle no results" do
      _post1 = Fabricate(:post, topic: topic_with_tags)
      search =
        described_class.new(
          { search_query: "ABDDCDCEDGDG", order: "fake" },
          bot_user: bot_user,
          llm: llm,
        )

      results = search.invoke(&progress_blk)

      expect(results[:args]).to eq({ search_query: "ABDDCDCEDGDG", order: "fake" })
      expect(results[:rows]).to eq([])
    end

    describe "semantic search" do
      let(:query) { "this is an expanded search" }
      after { DiscourseAi::Embeddings::SemanticSearch.clear_cache_for(query) }

      it "supports semantic search when enabled" do
        SiteSetting.ai_embeddings_semantic_search_hyde_model = "fake:fake"
        SiteSetting.ai_embeddings_semantic_search_enabled = true
        SiteSetting.ai_embeddings_discourse_service_api_endpoint = "http://test.com"

        hyde_embedding = [0.049382, 0.9999]
        EmbeddingsGenerationStubs.discourse_service(
          SiteSetting.ai_embeddings_model,
          query,
          hyde_embedding,
        )

        post1 = Fabricate(:post, topic: topic_with_tags)
        search =
          described_class.new(
            { search_query: "hello world, sam", status: "public" },
            llm: llm,
            bot_user: bot_user,
          )

        DiscourseAi::Embeddings::VectorRepresentations::BgeLargeEn
          .any_instance
          .expects(:asymmetric_topics_similarity_search)
          .returns([post1.topic_id])

        results =
          DiscourseAi::Completions::Llm.with_prepared_responses(["<ai>#{query}</ai>"]) do
            search.invoke(&progress_blk)
          end

        expect(results[:args]).to eq({ search_query: "hello world, sam", status: "public" })
        expect(results[:rows].length).to eq(1)
      end
    end

    it "supports subfolder properly" do
      Discourse.stubs(:base_path).returns("/subfolder")

      post1 = Fabricate(:post, topic: topic_with_tags)

      search =
        described_class.new({ limit: 1, user: post1.user.username }, bot_user: bot_user, llm: llm)

      results = search.invoke(&progress_blk)
      expect(results[:rows].to_s).to include("/subfolder" + post1.url)
    end

    it "passes on all search params" do
      params =
        described_class.signature[:parameters]
          .map do |param|
            if param[:type] == "integer"
              [param[:name], 1]
            else
              [param[:name], "test"]
            end
          end
          .to_h
          .symbolize_keys

      search = described_class.new(params, bot_user: bot_user, llm: llm)
      results = search.invoke(&progress_blk)

      expect(results[:args]).to eq(params)
    end

    it "returns rich topic information" do
      post1 = Fabricate(:post, like_count: 1, topic: topic_with_tags)
      search = described_class.new({ user: post1.user.username }, bot_user: bot_user, llm: llm)
      post1.topic.update!(views: 100, posts_count: 2, like_count: 10)

      results = search.invoke(&progress_blk)

      row = results[:rows].first
      category = row[results[:column_names].index("category")]

      expect(category).to eq("animals > amazing-cat")

      tags = row[results[:column_names].index("tags")]
      expect(tags).to eq("funny, sad")

      likes = row[results[:column_names].index("likes")]
      expect(likes).to eq(1)

      username = row[results[:column_names].index("username")]
      expect(username).to eq(post1.user.username)

      likes = row[results[:column_names].index("topic_likes")]
      expect(likes).to eq(10)

      views = row[results[:column_names].index("topic_views")]
      expect(views).to eq(100)

      replies = row[results[:column_names].index("topic_replies")]
      expect(replies).to eq(1)
    end
  end
end
