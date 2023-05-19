#frozen_string_literal: true

require_relative "../../../../support/openai_completions_inference_stubs"

RSpec.describe DiscourseAi::AiBot::Commands::SummarizeCommand do
  fab!(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }
  fab!(:bot) { DiscourseAi::AiBot::Bot.as(bot_user) }

  describe "#process" do
    it "can generate correct info" do
      post = Fabricate(:post)

      summarizer = described_class.new(bot, post)
      info = summarizer.process("#{post.topic_id} why did it happen?")

      expect(info).to include("why did it happen?")
      expect(info).to include(post.raw)
      expect(info).to include(post.user.username)
    end

    it "protects hidden data" do
      category = Fabricate(:category)
      category.set_permissions({})
      category.save!

      topic = Fabricate(:topic, category_id: category.id)
      post = Fabricate(:post, topic: topic)

      summarizer = described_class.new(bot, post)
      info = summarizer.process("#{post.topic_id} why did it happen?")

      expect(info).not_to include(post.raw)
    end
  end
end
