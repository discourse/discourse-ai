#frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Commands::ReadCommand do
  fab!(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }

  describe "#process" do
    it "can read a topic" do
      post1 = Fabricate(:post, raw: "hello there")
      Fabricate(:post, raw: "mister sam", topic: post1.topic)

      read = described_class.new(bot_user, post1)

      results = read.process(topic_id: post1.topic_id)

      expect(results[:topic_id]).to eq(post1.topic_id)
      expect(results[:content]).to include("hello")
      expect(results[:content]).to include("sam")
      expect(read.description_args).to eq(title: post1.topic.title, url: post1.topic.relative_url)
    end
  end
end
