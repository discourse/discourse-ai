# frozen_string_literal: true

RSpec.describe DiscourseAi::Embeddings::SemanticSearch do
  fab!(:post) { Fabricate(:post) }
  fab!(:user) { Fabricate(:user) }
  let(:model_name) { "msmarco-distilbert-base-v4" }
  let(:query) { "test_query" }

  let(:model) { DiscourseAi::Embeddings::Model.instantiate(model_name) }
  let(:subject) { described_class.new(Guardian.new(user), model) }

  describe "#search_for_topics" do
    def stub_candidate_ids(candidate_ids)
      DiscourseAi::Embeddings::Topic
        .any_instance
        .expects(:asymmetric_semantic_search)
        .returns(candidate_ids)
    end

    it "returns the first post of a topic included in the asymmetric search results" do
      stub_candidate_ids([post.topic_id])

      posts = subject.search_for_topics(query)

      expect(posts).to contain_exactly(post)
    end

    describe "applies different scopes to the candidates" do
      context "when the topic is not visible" do
        it "returns an empty list" do
          post.topic.update!(visible: false)
          stub_candidate_ids([post.topic_id])

          posts = subject.search_for_topics(query)

          expect(posts).to be_empty
        end
      end

      context "when the post is not public" do
        it "returns an empty list" do
          pm_post = Fabricate(:private_message_post)
          stub_candidate_ids([pm_post.topic_id])

          posts = subject.search_for_topics(query)

          expect(posts).to be_empty
        end
      end

      context "when the post type is not visible" do
        it "returns an empty list" do
          post.update!(post_type: Post.types[:whisper])
          stub_candidate_ids([post.topic_id])

          posts = subject.search_for_topics(query)

          expect(posts).to be_empty
        end
      end

      context "when the post is not the first post in the topic" do
        it "returns an empty list" do
          reply = Fabricate(:reply)
          reply.topic.first_post.trash!
          stub_candidate_ids([reply.topic_id])

          posts = subject.search_for_topics(query)

          expect(posts).to be_empty
        end
      end

      context "when the post is not a candidate" do
        it "doesn't include it in the results" do
          post_2 = Fabricate(:post)
          stub_candidate_ids([post.topic_id])

          posts = subject.search_for_topics(query)

          expect(posts).not_to include(post_2)
        end
      end
    end
  end
end
