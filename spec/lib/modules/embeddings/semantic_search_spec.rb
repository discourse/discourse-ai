# frozen_string_literal: true

RSpec.describe DiscourseAi::Embeddings::SemanticSearch do
  fab!(:post)
  fab!(:user)

  let(:query) { "test_query" }
  let(:subject) { described_class.new(Guardian.new(user)) }

  before { SiteSetting.ai_embeddings_semantic_search_hyde_model = "fake:fake" }

  describe "#search_for_topics" do
    let(:hypothetical_post) { "This is an hypothetical post generated from the keyword test_query" }

    before do
      SiteSetting.ai_embeddings_discourse_service_api_endpoint = "http://test.com"

      hyde_embedding = [0.049382, 0.9999]
      EmbeddingsGenerationStubs.discourse_service(
        SiteSetting.ai_embeddings_model,
        hypothetical_post,
        hyde_embedding,
      )
    end

    after { described_class.clear_cache_for(query) }

    def stub_candidate_ids(candidate_ids)
      DiscourseAi::Embeddings::VectorRepresentations::BgeLargeEn
        .any_instance
        .expects(:asymmetric_topics_similarity_search)
        .returns(candidate_ids)
    end

    def trigger_search(query)
      DiscourseAi::Completions::Llm.with_prepared_responses(["<ai>#{hypothetical_post}</ai>"]) do
        subject.search_for_topics(query)
      end
    end

    it "returns the first post of a topic included in the asymmetric search results" do
      stub_candidate_ids([post.topic_id])

      posts = trigger_search(query)

      expect(posts).to contain_exactly(post)
    end

    describe "applies different scopes to the candidates" do
      context "when the topic is not visible" do
        it "returns an empty list" do
          post.topic.update!(visible: false)
          stub_candidate_ids([post.topic_id])

          posts = trigger_search(query)

          expect(posts).to be_empty
        end
      end

      context "when the post is not public" do
        it "returns an empty list" do
          pm_post = Fabricate(:private_message_post)
          stub_candidate_ids([pm_post.topic_id])

          posts = trigger_search(query)

          expect(posts).to be_empty
        end
      end

      context "when the post type is not visible" do
        it "returns an empty list" do
          post.update!(post_type: Post.types[:whisper])
          stub_candidate_ids([post.topic_id])

          posts = trigger_search(query)

          expect(posts).to be_empty
        end
      end

      context "when the post is not the first post in the topic" do
        it "returns an empty list" do
          reply = Fabricate(:reply)
          reply.topic.first_post.trash!
          stub_candidate_ids([reply.topic_id])

          posts = trigger_search(query)

          expect(posts).to be_empty
        end
      end

      context "when the post is not a candidate" do
        it "doesn't include it in the results" do
          post_2 = Fabricate(:post)
          stub_candidate_ids([post.topic_id])

          posts = trigger_search(query)

          expect(posts).not_to include(post_2)
        end
      end

      context "when the post belongs to a secured category" do
        fab!(:group)
        fab!(:private_category) { Fabricate(:private_category, group: group) }

        before do
          post.topic.update!(category: private_category)
          stub_candidate_ids([post.topic_id])
        end

        it "returns an empty list" do
          posts = trigger_search(query)

          expect(posts).to be_empty
        end

        it "returns the results if the user has access to the category" do
          group.add(user)

          posts = trigger_search(query)

          expect(posts).to contain_exactly(post)
        end

        context "while searching as anon" do
          it "returns an empty list" do
            posts =
              DiscourseAi::Completions::Llm.with_prepared_responses(
                ["<ai>#{hypothetical_post}</ai>"],
              ) { described_class.new(Guardian.new(nil)).search_for_topics(query) }

            expect(posts).to be_empty
          end
        end
      end
    end
  end
end
