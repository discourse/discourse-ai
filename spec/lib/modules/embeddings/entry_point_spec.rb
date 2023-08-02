# frozen_string_literal: true

require "rails_helper"

describe DiscourseAi::Embeddings::EntryPoint do
  fab!(:user) { Fabricate(:user) }

  describe "registering event callbacks" do
    context "when creating a topic" do
      let(:creator) do
        PostCreator.new(
          user,
          raw: "this is the new content for my topic",
          title: "this is my new topic title",
        )
      end

      it "queues a job on create if embeddings is enabled" do
        SiteSetting.ai_embeddings_enabled = true

        expect { creator.create }.to change(Jobs::GenerateEmbeddings.jobs, :size).by(1)
      end

      it "does nothing if sentiment analysis is disabled" do
        SiteSetting.ai_embeddings_enabled = false

        expect { creator.create }.not_to change(Jobs::GenerateEmbeddings.jobs, :size)
      end
    end
  end

  describe "TopicQuery extensions" do
    describe "#list_semantic_related_topics" do
      subject(:topic_query) { TopicQuery.new(user) }

      fab!(:target) { Fabricate(:topic) }

      def stub_semantic_search_with(results)
        DiscourseAi::Embeddings::SemanticRelated.expects(:related_topic_ids_for).returns(results)
      end

      context "when the semantic search returns an unlisted topic" do
        fab!(:unlisted_topic) { Fabricate(:topic, visible: false) }

        before { stub_semantic_search_with([unlisted_topic.id]) }

        it "filters it out" do
          expect(topic_query.list_semantic_related_topics(target).topics).to be_empty
        end
      end

      context "when the semantic search returns a private topic" do
        fab!(:private_topic) { Fabricate(:private_message_topic) }

        before { stub_semantic_search_with([private_topic.id]) }

        it "filters it out" do
          expect(topic_query.list_semantic_related_topics(target).topics).to be_empty
        end
      end

      context "when the semantic search returns a topic from a restricted category" do
        fab!(:group) { Fabricate(:group) }
        fab!(:category) { Fabricate(:private_category, group: group) }
        fab!(:secured_category_topic) { Fabricate(:topic, category: category) }

        before { stub_semantic_search_with([secured_category_topic.id]) }

        it "filters it out" do
          expect(topic_query.list_semantic_related_topics(target).topics).to be_empty
        end

        it "doesn't filter it out if the user has access to the category" do
          group.add(user)

          expect(topic_query.list_semantic_related_topics(target).topics).to contain_exactly(
            secured_category_topic,
          )
        end
      end

      context "when the semantic search returns a closed topic and we explicitly exclude them" do
        fab!(:closed_topic) { Fabricate(:topic, closed: true) }

        before do
          SiteSetting.ai_embeddings_semantic_related_include_closed_topics = false
          stub_semantic_search_with([closed_topic.id])
        end

        it "filters it out" do
          expect(topic_query.list_semantic_related_topics(target).topics).to be_empty
        end
      end

      context "when the semantic search returns public topics" do
        fab!(:normal_topic_1) { Fabricate(:topic) }
        fab!(:normal_topic_2) { Fabricate(:topic) }
        fab!(:normal_topic_3) { Fabricate(:topic) }
        fab!(:closed_topic) { Fabricate(:topic, closed: true) }

        before do
          stub_semantic_search_with(
            [closed_topic.id, normal_topic_1.id, normal_topic_2.id, normal_topic_3.id],
          )
        end

        it "filters it out" do
          expect(topic_query.list_semantic_related_topics(target).topics).to eq(
            [closed_topic, normal_topic_1, normal_topic_2, normal_topic_3],
          )
        end

        it "returns the plugin limit for the number of results" do
          SiteSetting.ai_embeddings_semantic_related_topics = 2

          expect(topic_query.list_semantic_related_topics(target).topics).to contain_exactly(
            closed_topic,
            normal_topic_1,
          )
        end
      end
    end
  end
end
