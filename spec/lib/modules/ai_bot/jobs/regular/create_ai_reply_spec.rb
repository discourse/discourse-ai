# frozen_string_literal: true

RSpec.describe Jobs::CreateAiReply do
  before { SiteSetting.ai_bot_enabled = true }

  describe "#execute" do
    fab!(:topic) { Fabricate(:topic) }
    fab!(:post) { Fabricate(:post, topic: topic) }

    let(:expected_response) do
      "Hello this is a bot and what you just said is an interesting question"
    end

    before { SiteSetting.min_personal_message_post_length = 5 }

    it "adds a reply from the bot" do
      DiscourseAi::Completions::Llm.with_prepared_responses([expected_response]) do
        subject.execute(
          post_id: topic.first_post.id,
          bot_user_id: DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID,
        )
      end

      expect(topic.posts.last.raw).to eq(expected_response)
    end
  end
end
