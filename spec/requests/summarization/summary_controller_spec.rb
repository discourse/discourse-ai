# frozen_string_literal: true

RSpec.describe DiscourseAi::Summarization::SummaryController do
  describe "#summary" do
    fab!(:topic) { Fabricate(:topic, highest_post_number: 2) }
    fab!(:post_1) { Fabricate(:post, topic: topic, post_number: 1) }
    fab!(:post_2) { Fabricate(:post, topic: topic, post_number: 2) }

    before do
      assign_fake_provider_to(:ai_summarization_model)
      SiteSetting.ai_summarization_enabled = true
    end

    context "for anons" do
      it "returns a 404 if there is no cached summary" do
        get "/discourse-ai/summarization/t/#{topic.id}.json"

        expect(response.status).to eq(404)
      end

      it "returns a cached summary" do
        section =
          AiSummary.create!(
            target: topic,
            summarized_text: "test",
            algorithm: "test",
            original_content_sha: "test",
          )

        get "/discourse-ai/summarization/t/#{topic.id}.json"

        expect(response.status).to eq(200)

        summary = response.parsed_body
        expect(summary.dig("ai_topic_summary", "summarized_text")).to eq(section.summarized_text)
      end
    end

    context "when the user is a member of an allowlisted group" do
      fab!(:user) { Fabricate(:leader) }

      before do
        sign_in(user)
        Group.find(Group::AUTO_GROUPS[:trust_level_3]).add(user)
      end

      it "returns a 404 if there is no topic" do
        invalid_topic_id = 999

        get "/discourse-ai/summarization/t/#{invalid_topic_id}.json"

        expect(response.status).to eq(404)
      end

      it "returns a 403 if not allowed to see the topic" do
        pm = Fabricate(:private_message_topic)

        get "/discourse-ai/summarization/t/#{pm.id}.json"

        expect(response.status).to eq(403)
      end

      it "returns a summary" do
        summary_text = "This is a summary"
        DiscourseAi::Completions::Llm.with_prepared_responses([summary_text]) do
          get "/discourse-ai/summarization/t/#{topic.id}.json"

          expect(response.status).to eq(200)
          summary = response.parsed_body["ai_topic_summary"]
          section = AiSummary.last

          expect(section.summarized_text).to eq(summary_text)
          expect(summary["summarized_text"]).to eq(section.summarized_text)
          expect(summary["algorithm"]).to eq("fake")
          expect(summary["outdated"]).to eq(false)
          expect(summary["can_regenerate"]).to eq(true)
          expect(summary["new_posts_since_summary"]).to be_zero
        end
      end

      it "signals the summary is outdated" do
        get "/discourse-ai/summarization/t/#{topic.id}.json"

        Fabricate(:post, topic: topic, post_number: 3)
        topic.update!(highest_post_number: 3)

        get "/discourse-ai/summarization/t/#{topic.id}.json"
        expect(response.status).to eq(200)
        summary = response.parsed_body["ai_topic_summary"]

        expect(summary["outdated"]).to eq(true)
        expect(summary["new_posts_since_summary"]).to eq(1)
      end
    end

    context "when the user is not a member of an allowlisted group" do
      fab!(:user)

      before { sign_in(user) }

      it "return a 404 if there is no cached summary" do
        get "/discourse-ai/summarization/t/#{topic.id}.json"

        expect(response.status).to eq(404)
      end

      it "returns a cached summary" do
        section =
          AiSummary.create!(
            target: topic,
            summarized_text: "test",
            algorithm: "test",
            original_content_sha: "test",
          )

        get "/discourse-ai/summarization/t/#{topic.id}.json"

        expect(response.status).to eq(200)

        summary = response.parsed_body
        expect(summary.dig("ai_topic_summary", "summarized_text")).to eq(section.summarized_text)
      end
    end
  end
end
