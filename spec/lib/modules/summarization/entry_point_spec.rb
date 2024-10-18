# frozen_string_literal: true

RSpec.describe DiscourseAi::Summarization::EntryPoint do
  before do
    assign_fake_provider_to(:ai_summarization_model)
    SiteSetting.ai_summarization_enabled = true
  end

  fab!(:user)

  describe "#inject_into" do
    describe "hot topics gist summarization" do
      fab!(:topic_ai_gist)
      fab!(:regular_summary) { Fabricate(:ai_summary, target: topic_ai_gist.target) }

      before { TopicHotScore.create!(topic_id: topic_ai_gist.target_id, score: 1.0) }

      let(:topic_query) { TopicQuery.new(user) }

      describe "topic_query_create_list_topics modifier" do
        context "when hot topic summarization is enabled" do
          before { SiteSetting.ai_summarize_max_hot_topics_gists_per_batch = 100 }

          it "preloads only gist summaries" do
            gist_topic = topic_query.list_hot.topics.find { |t| t.id == topic_ai_gist.target_id }

            expect(gist_topic.ai_summaries.size).to eq(1)
            expect(gist_topic.ai_summaries.first).to eq(topic_ai_gist)
          end

          it "doesn't filter out hot topics without summaries" do
            TopicHotScore.create!(topic_id: Fabricate(:topic).id, score: 1.0)

            expect(topic_query.list_hot.topics.size).to eq(2)
          end
        end
      end

      describe "topic_list_item serializer's ai_summary" do
        context "when hot topic summarization is disabled" do
          it "doesn't include summaries" do
            gist_topic = topic_query.list_hot.topics.find { |t| t.id == topic_ai_gist.target_id }

            serialized =
              TopicListItemSerializer.new(gist_topic, scope: Guardian.new, root: false).as_json

            expect(serialized.has_key?(:ai_topic_gist)).to eq(false)
          end
        end

        context "when hot topics summarization is enabled" do
          before { SiteSetting.ai_summarize_max_hot_topics_gists_per_batch = 100 }

          it "includes the summary" do
            gist_topic = topic_query.list_hot.topics.find { |t| t.id == topic_ai_gist.target_id }

            serialized =
              TopicListItemSerializer.new(
                gist_topic,
                scope: Guardian.new,
                root: false,
                filter: :hot,
              ).as_json

            expect(serialized[:ai_topic_gist]).to be_present
          end

          it "doesn't include the summary when looking at other topic lists" do
            gist_topic = topic_query.list_hot.topics.find { |t| t.id == topic_ai_gist.target_id }

            serialized =
              TopicListItemSerializer.new(
                gist_topic,
                scope: Guardian.new,
                root: false,
                filter: :latest,
              ).as_json

            expect(serialized[:ai_topic_gist]).to be_nil
          end
        end
      end
    end
  end

  describe "#on topic_hot_scores_updated" do
    it "queues a job to generate gists" do
      expect { DiscourseEvent.trigger(:topic_hot_scores_updated) }.to change(
        Jobs::HotTopicsGistBatch.jobs,
        :size,
      ).by(1)
    end
  end
end
