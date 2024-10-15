# frozen_string_literal: true

RSpec.describe DiscourseAi::Summarization::Strategies::TopicGist do
  subject(:gist) { described_class.new(topic) }

  fab!(:topic) { Fabricate(:topic, highest_post_number: 25) }
  fab!(:post_1) { Fabricate(:post, topic: topic, post_number: 1) }
  fab!(:post_2) { Fabricate(:post, topic: topic, post_number: 2) }

  describe "#targets_data" do
    context "when the topic has more than 20 posts" do
      before do
        offset = 3 # Already created posts 1 and 2
        (topic.highest_post_number - 2).times do |i|
          Fabricate(:post, topic: topic, post_number: i + offset)
        end
      end

      it "includes the OP and the last 20 posts" do
        content = gist.targets_data
        post_numbers = content[:contents].map { |c| c[:id] }

        expected = (6..25).to_a << 1

        expect(post_numbers).to contain_exactly(*expected)
      end
    end

    it "only includes visible posts" do
      post_2.update!(hidden: true)

      post_numbers = gist.targets_data[:contents].map { |c| c[:id] }

      expect(post_numbers).to contain_exactly(1)
    end

    it "doesn't include posts without users" do
      post_2.update!(user_id: nil)

      post_numbers = gist.targets_data[:contents].map { |c| c[:id] }

      expect(post_numbers).to contain_exactly(1)
    end

    it "doesn't include whispers" do
      post_2.update!(post_type: Post.types[:whisper])

      post_numbers = gist.targets_data[:contents].map { |c| c[:id] }

      expect(post_numbers).to contain_exactly(1)
    end

    context "when the topic has embed content cached" do
      it "embed content is used instead of the raw text" do
        topic_embed =
          Fabricate(
            :topic_embed,
            topic: topic,
            embed_content_cache: "<p>hello world new post :D</p>",
          )

        content = gist.targets_data

        op_content = content[:contents].first[:text]

        expect(op_content).to include(topic_embed.embed_content_cache)
      end
    end
  end
end
