# frozen_string_literal: true

describe DiscourseAi::Embeddings::EntryPoint do
  fab!(:user) { Fabricate(:user) }

  describe "SemanticTopicQuery extension" do
    before { SiteSetting.ai_embeddings_model = "bge-large-en" }

    describe "#list_semantic_related_topics" do
      subject(:topic_query) { DiscourseAi::Embeddings::SemanticTopicQuery.new(user) }

      fab!(:target) { Fabricate(:topic) }

      def stub_semantic_search_with(results)
        DiscourseAi::Embeddings::VectorRepresentations::BgeLargeEn
          .any_instance
          .expects(:symmetric_topics_similarity_search)
          .returns(results.concat([target.id]))
      end

      after { DiscourseAi::Embeddings::SemanticRelated.clear_cache_for(target) }

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

      context "when the semantic search returns a muted topic" do
        it "filters it out" do
          category = Fabricate(:category_with_definition)
          topic = Fabricate(:topic, category: category)
          CategoryUser.create!(
            user_id: user.id,
            category_id: category.id,
            notification_level: CategoryUser.notification_levels[:muted],
          )
          stub_semantic_search_with([topic.id])
          expect(topic_query.list_semantic_related_topics(target).topics).not_to include(topic)
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
