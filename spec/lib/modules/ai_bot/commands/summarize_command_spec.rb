#frozen_string_literal: true

require_relative "../../../../support/openai_completions_inference_stubs"

RSpec.describe DiscourseAi::AiBot::Commands::SummarizeCommand do
  fab!(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }

  describe "#process" do
    it "can generate correct info" do
      post = Fabricate(:post)

      WebMock.stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: JSON.dump({ choices: [{ message: { content: "summary stuff" } }] }),
      )

      summarizer = described_class.new(bot_user: bot_user, args: nil, post: post)
      info = summarizer.process(topic_id: post.topic_id, guidance: "why did it happen?")

      expect(info).to include("Topic summarized")
      expect(summarizer.custom_raw).to include("summary stuff")
      expect(summarizer.chain_next_response).to eq(false)
    end

    it "protects hidden data" do
      category = Fabricate(:category)
      category.set_permissions({})
      category.save!

      topic = Fabricate(:topic, category_id: category.id)
      post = Fabricate(:post, topic: topic)

      summarizer = described_class.new(bot_user: bot_user, post: post, args: nil)
      info = summarizer.process(topic_id: post.topic_id, guidance: "why did it happen?")

      expect(info).not_to include(post.raw)

      expect(summarizer.custom_raw).to eq(I18n.t("discourse_ai.ai_bot.topic_not_found"))
    end
  end
end
