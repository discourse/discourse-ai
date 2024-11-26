# frozen_string_literal: true

RSpec.describe DiscourseAi::Summarization::EntryPoint do
  before do
    assign_fake_provider_to(:ai_summarization_model)
    SiteSetting.ai_summarization_enabled = true
    SiteSetting.ai_summarize_max_topic_gists_per_batch = 100
  end

  fab!(:user)

  describe "#inject_into" do
    describe "hot topics gist summarization" do
      fab!(:topic_ai_gist)

      before { TopicHotScore.create!(topic_id: topic_ai_gist.target_id, score: 1.0) }

      let(:topic_query) { TopicQuery.new(user) }

      describe "topic_query_create_list_topics modifier" do
        context "when hot topic summarization is enabled" do
          it "doesn't duplicate records when there more than one summary type" do
            Fabricate(:ai_summary, target: topic_ai_gist.target)

            expect(topic_query.list_hot.topics.map(&:id)).to contain_exactly(
              topic_ai_gist.target_id,
            )
          end

          it "doesn't exclude records when the topic has a single different summary" do
            regular_summary_2 = Fabricate(:ai_summary)
            TopicHotScore.create!(topic_id: regular_summary_2.target_id, score: 1.0)

            expect(topic_query.list_hot.topics.map(&:id)).to contain_exactly(
              regular_summary_2.target_id,
              topic_ai_gist.target_id,
            )
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
          fab!(:group)

          before do
            group.add(user)
            SiteSetting.ai_hot_topic_gists_allowed_groups = group.id
            SiteSetting.ai_summarize_max_topic_gists_per_batch = 100
          end

          it "includes the summary" do
            gist_topic = topic_query.list_hot.topics.find { |t| t.id == topic_ai_gist.target_id }

            serialized =
              TopicListItemSerializer.new(
                gist_topic,
                scope: Guardian.new(user),
                root: false,
                filter: :hot,
              ).as_json

            expect(serialized[:ai_topic_gist]).to be_present
          end

          it "doesn't include the summary when the user is not a member of the opt-in group" do
            SiteSetting.ai_hot_topic_gists_allowed_groups = ""

            gist_topic = topic_query.list_hot.topics.find { |t| t.id == topic_ai_gist.target_id }

            serialized =
              TopicListItemSerializer.new(
                gist_topic,
                scope: Guardian.new(user),
                root: false,
                filter: :hot,
              ).as_json

            expect(serialized[:ai_topic_gist]).to be_nil
          end

          it "works when the topic has whispers" do
            SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}"
            admin = Fabricate(:admin)
            group.add(admin)
            # We are testing a scenario where AR could get confused if we don't use `references`.

            first = create_post(raw: "this is the first post", title: "super amazing title")

            _whisper =
              create_post(
                topic_id: first.topic.id,
                post_type: Post.types[:whisper],
                raw: "this is a whispered reply",
              )

            Fabricate(:topic_ai_gist, target: first.topic)
            topic_id = first.topic.id
            TopicUser.update_last_read(admin, topic_id, first.post_number, 1, 1)
            TopicUser.change(
              admin.id,
              topic_id,
              notification_level: TopicUser.notification_levels[:tracking],
            )

            gist_topic = TopicQuery.new(admin).list_unread.topics.find { |t| t.id == topic_id }

            serialized =
              TopicListItemSerializer.new(
                gist_topic,
                scope: Guardian.new(admin),
                root: false,
                filter: :unread,
              ).as_json

            expect(serialized[:ai_topic_gist]).to be_present
          end

          it "doesn't include the summary if it's not a gist" do
            regular_summary_2 = Fabricate(:ai_summary)
            TopicHotScore.create!(topic_id: regular_summary_2.target_id, score: 1.0)

            hot_topic = topic_query.list_hot.topics.find { |t| t.id == regular_summary_2.target_id }

            serialized =
              TopicListItemSerializer.new(
                hot_topic,
                scope: Guardian.new(user),
                root: false,
                filter: :hot,
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
