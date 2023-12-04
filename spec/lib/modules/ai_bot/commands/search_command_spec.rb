#frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Commands::SearchCommand do
  before { SearchIndexer.enable }
  after { SearchIndexer.disable }

  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }
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

  it "can properly list options" do
    options = described_class.options
    expect(options.length).to eq(1)
    expect(options.first.name.to_s).to eq("base_query")
    expect(options.first.localized_name).not_to include("Translation missing:")
    expect(options.first.localized_description).not_to include("Translation missing:")
  end

  describe "#process" do
    it "can retreive options from persona correctly" do
      persona =
        Fabricate(
          :ai_persona,
          allowed_group_ids: [Group::AUTO_GROUPS[:admins]],
          commands: [["SearchCommand", { "base_query" => "#funny" }]],
        )
      Group.refresh_automatic_groups!

      bot = DiscourseAi::AiBot::Bot.as(bot_user, persona_id: persona.id, user: admin)
      search_post = Fabricate(:post, topic: topic_with_tags)

      bot_post = Fabricate(:post)

      search = described_class.new(bot: bot, post: bot_post, args: nil)

      results = search.process(order: "latest")
      expect(results[:rows].length).to eq(1)

      search_post.topic.tags = []
      search_post.topic.save!

      # no longer has the tag funny
      results = search.process(order: "latest")
      expect(results[:rows].length).to eq(0)
    end

    it "can handle no results" do
      post1 = Fabricate(:post, topic: topic_with_tags)
      search = described_class.new(bot: nil, post: post1, args: nil)

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

        post1 = Fabricate(:post, topic: topic_with_tags)
        search = described_class.new(bot: nil, post: post1, args: nil)

        DiscourseAi::Embeddings::VectorRepresentations::AllMpnetBaseV2
          .any_instance
          .expects(:asymmetric_topics_similarity_search)
          .returns([post1.topic_id])

        results =
          DiscourseAi::Completions::Llm.with_prepared_responses(["<ai>#{query}</ai>"]) do
            search.process(search_query: "hello world, sam", status: "public")
          end

        expect(results[:args]).to eq({ search_query: "hello world, sam", status: "public" })
        expect(results[:rows].length).to eq(1)
      end
    end

    it "supports subfolder properly" do
      Discourse.stubs(:base_path).returns("/subfolder")

      post1 = Fabricate(:post, topic: topic_with_tags)

      search = described_class.new(bot: nil, post: post1, args: nil)

      results = search.process(limit: 1, user: post1.user.username)
      expect(results[:rows].to_s).to include("/subfolder" + post1.url)
    end

    it "returns category and tags" do
      post1 = Fabricate(:post, topic: topic_with_tags)
      search = described_class.new(bot: nil, post: post1, args: nil)
      results = search.process(user: post1.user.username)

      row = results[:rows].first
      category = row[results[:column_names].index("category")]

      expect(category).to eq("animals > amazing-cat")

      tags = row[results[:column_names].index("tags")]
      expect(tags).to eq("funny, sad")
    end

    it "can handle limits" do
      post1 = Fabricate(:post, topic: topic_with_tags)
      _post2 = Fabricate(:post, user: post1.user)
      _post3 = Fabricate(:post, user: post1.user)

      # search has no built in support for limit: so handle it from the outside
      search = described_class.new(bot: nil, post: post1, args: nil)

      results = search.process(limit: 2, user: post1.user.username)

      expect(results[:rows].length).to eq(2)

      # just searching for everything
      results = search.process(order: "latest_topic")
      expect(results[:rows].length).to be > 1
    end
  end
end
