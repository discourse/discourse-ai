# frozen_string_literal: true

RSpec.describe Jobs::HotTopicsGistBatch do
  fab!(:topic_1) { Fabricate(:topic) }
  fab!(:post_1) { Fabricate(:post, topic: topic_1, post_number: 1) }
  fab!(:post_2) { Fabricate(:post, topic: topic_1, post_number: 2) }

  before do
    assign_fake_provider_to(:ai_summarization_model)
    SiteSetting.ai_summarization_enabled = true
    SiteSetting.ai_summarize_max_hot_topics_gists_per_batch = 100
  end

  describe "#execute" do
    context "when there is a topic with a hot score" do
      before { TopicHotScore.create!(topic_id: topic_1.id, score: 0.1) }

      it "does nothing if the plugin is disabled" do
        SiteSetting.discourse_ai_enabled = false

        subject.execute({})

        gist = AiSummary.gist.find_by(target: topic_1)
        expect(gist).to be_nil
      end

      it "does nothing if the summarization module is disabled" do
        SiteSetting.ai_summarization_enabled = false

        subject.execute({})

        gist = AiSummary.gist.find_by(target: topic_1)
        expect(gist).to be_nil
      end

      it "does nothing if hot topics summarization is disabled" do
        SiteSetting.ai_summarize_max_hot_topics_gists_per_batch = 0

        subject.execute({})

        gist = AiSummary.gist.find_by(target: topic_1)
        expect(gist).to be_nil
      end

      it "creates a gist" do
        gist_result = "I'm a gist"

        DiscourseAi::Completions::Llm.with_prepared_responses([gist_result]) { subject.execute({}) }

        gist = AiSummary.gist.find_by(target: topic_1)
        expect(gist.summarized_text).to eq(gist_result)
      end

      context "when we already generated a gist of it" do
        fab!(:ai_gist) do
          Fabricate(
            :topic_ai_gist,
            target: topic_1,
            original_content_sha: AiSummary.build_sha("12"),
          )
        end

        it "does nothing if the gist is up to date" do
          updated_gist = "They updated me :("

          DiscourseAi::Completions::Llm.with_prepared_responses([updated_gist]) do
            subject.execute({})
          end

          gist = AiSummary.gist.find_by(target: topic_1)
          expect(AiSummary.gist.where(target: topic_1).count).to eq(1)
          expect(gist.summarized_text).not_to eq(updated_gist)
          expect(gist.original_content_sha).to eq(ai_gist.original_content_sha)
        end

        it "regenerates it if it's outdated" do
          Fabricate(:post, topic: topic_1, post_number: 3)
          gist_result = "They updated me"

          DiscourseAi::Completions::Llm.with_prepared_responses([gist_result]) do
            subject.execute({})
          end

          gist = AiSummary.gist.find_by(target: topic_1)
          expect(gist.summarized_text).to eq(gist_result)
          expect(gist.original_content_sha).to eq(AiSummary.build_sha("123"))
        end
      end
    end

    context "when there is a topic but it doesn't have a hot score" do
      it "does nothing" do
        subject.execute({})

        gist = AiSummary.gist.find_by(target: topic_1)
        expect(gist).to be_nil
      end
    end

    context "when there are multiple hot topics" do
      fab!(:topic_2) { Fabricate(:topic) }
      fab!(:post_2_1) { Fabricate(:post, topic: topic_2, post_number: 1) }
      fab!(:post_2_2) { Fabricate(:post, topic: topic_2, post_number: 2) }

      before do
        TopicHotScore.create!(topic_id: topic_1.id, score: 0.2)
        TopicHotScore.create!(topic_id: topic_2.id, score: 0.4)
      end

      it "processes them by score order" do
        topic_1_gist = "I'm gist of topic 1"
        topic_2_gist = "I'm gist of topic 2"

        DiscourseAi::Completions::Llm.with_prepared_responses([topic_2_gist, topic_1_gist]) do
          subject.execute({})
        end

        gist = AiSummary.gist.find_by(target: topic_1)
        expect(gist.summarized_text).to eq(topic_1_gist)

        gist_2 = AiSummary.gist.find_by(target: topic_2)
        expect(gist_2.summarized_text).to eq(topic_2_gist)
      end
    end
  end
end
