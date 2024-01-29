#frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Tools::Summarize do
  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("open_ai:gpt-3.5-turbo") }
  let(:progress_blk) { Proc.new {} }

  before { SiteSetting.ai_bot_enabled = true }

  let(:summary) { "summary stuff" }

  describe "#process" do
    it "can generate correct info" do
      post = Fabricate(:post)

      DiscourseAi::Completions::Llm.with_prepared_responses([summary]) do
        summarization =
          described_class.new({ topic_id: post.topic_id, guidance: "why did it happen?" })
        info = summarization.invoke(bot_user, llm, &progress_blk)

        expect(info).to include("Topic summarized")
        expect(summarization.custom_raw).to include(summary)
        expect(summarization.chain_next_response?).to eq(false)
      end
    end

    it "protects hidden data" do
      category = Fabricate(:category)
      category.set_permissions({})
      category.save!

      topic = Fabricate(:topic, category_id: category.id)
      post = Fabricate(:post, topic: topic)

      DiscourseAi::Completions::Llm.with_prepared_responses([summary]) do
        summarization =
          described_class.new({ topic_id: post.topic_id, guidance: "why did it happen?" })
        info = summarization.invoke(bot_user, llm, &progress_blk)

        expect(info).not_to include(post.raw)

        expect(summarization.custom_raw).to eq(I18n.t("discourse_ai.ai_bot.topic_not_found"))
      end
    end
  end
end
