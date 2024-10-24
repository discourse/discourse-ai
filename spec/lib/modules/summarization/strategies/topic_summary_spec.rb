# frozen_string_literal: true

RSpec.describe DiscourseAi::Summarization::Strategies::TopicSummary do
  subject(:topic_summary) { described_class.new(topic) }

  fab!(:topic) { Fabricate(:topic, highest_post_number: 25) }
  fab!(:post_1) { Fabricate(:post, topic: topic, post_number: 1) }
  fab!(:post_2) { Fabricate(:post, topic: topic, post_number: 2) }

  describe "#targets_data" do
    shared_examples "includes only public-visible topics" do
      it "only includes visible posts" do
        post_2.update!(hidden: true)

        post_numbers = topic_summary.targets_data.map { |c| c[:id] }

        expect(post_numbers).to contain_exactly(1)
      end

      it "doesn't include posts without users" do
        post_2.update!(user_id: nil)

        post_numbers = topic_summary.targets_data.map { |c| c[:id] }

        expect(post_numbers).to contain_exactly(1)
      end

      it "doesn't include whispers" do
        post_2.update!(post_type: Post.types[:whisper])

        post_numbers = topic_summary.targets_data.map { |c| c[:id] }

        expect(post_numbers).to contain_exactly(1)
      end
    end

    context "when the topic has a best replies summary" do
      before { topic.update(has_summary: true) }

      it_behaves_like "includes only public-visible topics"
    end

    context "when the topic doesn't have a best replies summary" do
      before { topic.update(has_summary: false) }

      it_behaves_like "includes only public-visible topics"
    end

    context "when the topic has embed content cached" do
      it "embed content is used instead of the raw text" do
        topic_embed =
          Fabricate(
            :topic_embed,
            topic: topic,
            embed_content_cache: "<p>hello world new post :D</p>",
          )

        content = topic_summary.targets_data
        op_content = content.first[:text]

        expect(op_content).to include(topic_embed.embed_content_cache)
      end
    end
  end
end
