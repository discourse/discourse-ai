# frozen_string_literal: true

require_relative "../../../support/openai_completions_inference_stubs"

RSpec.describe DiscourseAi::AiBot::Bot do
  fab!(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT4_ID) }
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
      bot.max_commands_per_reply = 2

      expected_response = {
        function_call: {
          name: "search",
          arguments: { query: "test search" }.to_json,
        },
      }

      prompt = bot.bot_prompt_with_topic_context(second_post)

      req_opts = bot.reply_params.merge({ functions: bot.available_functions, stream: true })

      OpenAiCompletionsInferenceStubs.stub_streamed_response(
        prompt,
        [expected_response],
        model: bot.model_for,
        req_opts: req_opts,
      )

      prompt << { role: "function", content: "[]", name: "search" }

      OpenAiCompletionsInferenceStubs.stub_streamed_response(
        prompt,
        [content: "I found nothing, sorry"],
        model: bot.model_for,
        req_opts: req_opts,
      )

      bot.reply_to(second_post)

      last = second_post.topic.posts.order("id desc").first

      expect(last.raw).to include("<details>")
      expect(last.raw).to include("<summary>Search</summary>")
      expect(last.raw).not_to include("translation missing")
      expect(last.raw).to include("I found nothing")

      expect(last.post_custom_prompt.custom_prompt).to eq(
        [["[]", "search", "function"], ["I found nothing, sorry", bot_user.username]],
      )
    end
  end

  describe "#update_pm_title" do
    let(:expected_response) { "This is a suggested title" }

    before { SiteSetting.min_personal_message_post_length = 5 }

    it "updates the title using bot suggestions" do
      OpenAiCompletionsInferenceStubs.stub_response(
        bot.title_prompt(second_post),
        expected_response,
        model: bot.model_for,
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
