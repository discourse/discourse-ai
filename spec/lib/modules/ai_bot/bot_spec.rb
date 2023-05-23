# frozen_string_literal: true

require_relative "../../../support/openai_completions_inference_stubs"

RSpec.describe DiscourseAi::AiBot::Bot do
  fab!(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }
  fab!(:bot) { described_class.as(bot_user) }

  fab!(:user) { Fabricate(:user) }
  fab!(:pm) do
    Fabricate(
      :private_message_topic,
      title: "This is my special PM",
      user: user,
      topic_allowed_users: [
        Fabricate.build(:topic_allowed_user, user: user),
        Fabricate.build(:topic_allowed_user, user: bot_user),
      ],
    )
  end
  fab!(:first_post) { Fabricate(:post, topic: pm, user: user, raw: "This is a reply by the user") }
  fab!(:second_post) do
    Fabricate(:post, topic: pm, user: user, raw: "This is a second reply by the user")
  end

  describe "#system_prompt" do
    it "includes relevant context in system prompt" do
      bot.system_prompt_style!(:standard)

      SiteSetting.title = "My Forum"
      SiteSetting.site_description = "My Forum Description"

      system_prompt = bot.system_prompt(second_post)

      expect(system_prompt).to include(SiteSetting.title)
      expect(system_prompt).to include(SiteSetting.site_description)

      expect(system_prompt).to include(user.username)
    end
  end

  describe "#reply_to" do
    it "can respond to !search" do
      bot.system_prompt_style!(:simple)

      expected_response = "ok, searching...\n!search test search"

      prompt = bot.bot_prompt_with_topic_context(second_post)

      OpenAiCompletionsInferenceStubs.stub_streamed_response(
        prompt,
        [{ content: expected_response }],
        req_opts: bot.reply_params.merge(stream: true),
      )

      prompt << { role: "assistant", content: "!search test search" }
      prompt << { role: "user", content: "results: No results found" }

      OpenAiCompletionsInferenceStubs.stub_streamed_response(
        prompt,
        [{ content: "We are done now" }],
        req_opts: bot.reply_params.merge(stream: true),
      )

      bot.reply_to(second_post)

      last = second_post.topic.posts.order("id desc").first

      expect(last.raw).to include("<details>")
      expect(last.raw).to include("<summary>Search</summary>")
      expect(last.raw).not_to include("translation missing")
      expect(last.raw).to include("ok, searching...")
      expect(last.raw).to include("We are done now")

      expect(last.post_custom_prompt.custom_prompt.to_s).to include("We are done now")
    end
  end

  describe "#update_pm_title" do
    let(:expected_response) { "This is a suggested title" }

    before { SiteSetting.min_personal_message_post_length = 5 }

    it "updates the title using bot suggestions" do
      OpenAiCompletionsInferenceStubs.stub_response(
        [bot.title_prompt(second_post)],
        expected_response,
        req_opts: {
          temperature: 0.7,
          top_p: 0.9,
          max_tokens: 40,
        },
      )

      bot.update_pm_title(second_post)

      expect(pm.reload.title).to eq(expected_response)
    end
  end
end
