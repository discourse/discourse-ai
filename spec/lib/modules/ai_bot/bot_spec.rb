# frozen_string_literal: true

require_relative "../../../support/openai_completions_inference_stubs"

RSpec.describe DiscourseAi::AiBot::Bot do
  describe "#update_pm_title" do
    fab!(:topic) { Fabricate(:topic) }
    fab!(:post) { Fabricate(:post, topic: topic) }

    let(:expected_response) { "This is a suggested title" }

    before { SiteSetting.min_personal_message_post_length = 5 }

    before { SiteSetting.min_personal_message_post_length = 5 }

    it "updates the title using bot suggestions" do
      bot_user = User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID)
      OpenAiCompletionsInferenceStubs.stub_response(
        DiscourseAi::AiBot::OpenAiBot.new(bot_user).title_prompt(post),
        expected_response,
        req_opts: {
          temperature: 0.7,
          top_p: 0.9,
          max_tokens: 40,
        },
      )

      described_class.as(bot_user).update_pm_title(post)

      expect(topic.reload.title).to eq(expected_response)
    end
  end
end
