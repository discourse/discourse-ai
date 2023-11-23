# frozen_string_literal: true

class FakeBot < DiscourseAi::AiBot::Bot
  class Tokenizer
    def tokenize(text)
      text.split(" ")
    end
  end

  def tokenizer
    Tokenizer.new
  end

  def prompt_limit(allow_commands: false)
    10_000
  end

  def build_message(poster_username, content, system: false, function: nil)
    role = poster_username == bot_user.username ? "Assistant" : "Human"

    "#{role}: #{content}"
  end

  def submit_prompt(prompt, post: nil, prefer_low_cost: false)
    rows = @responses.shift
    rows.each { |data| yield data, lambda {} }
  end

  def get_delta(partial, context)
    partial
  end

  def add_response(response)
    @responses ||= []
    @responses << response
  end
end

describe FakeBot do
  before do
    SiteSetting.ai_bot_enabled_chat_bots = "gpt-4"
    SiteSetting.ai_bot_enabled = true
  end

  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT4_ID) }
  fab!(:post) { Fabricate(:post, raw: "hello world") }

  it "can handle command truncation for long messages" do
    bot = FakeBot.new(bot_user)

    tags_command = <<~TEXT
      <function_calls>
      <invoke>
      <tool_name>tags</tool_name>
      </invoke>
      </function_calls>
    TEXT

    bot.add_response(["hello this is a big test I am testing 123\n", "#{tags_command}\nabc"])
    bot.add_response(["this is the reply"])

    bot.reply_to(post)

    reply = post.topic.posts.order(:post_number).last

    expect(reply.raw).not_to include("abc")
    expect(reply.post_custom_prompt.custom_prompt.to_s).not_to include("abc")
    expect(reply.post_custom_prompt.custom_prompt.length).to eq(3)
    expect(reply.post_custom_prompt.custom_prompt[0][0]).to eq(
      "hello this is a big test I am testing 123\n#{tags_command.strip}",
    )
  end

  it "can handle command truncation for short bot messages" do
    bot = FakeBot.new(bot_user)

    tags_command = <<~TEXT
      _calls>
      <invoke>
      <tool_name>tags</tool_name>
      </invoke>
      </function_calls>
    TEXT

    bot.add_response(["hello\n<function", "#{tags_command}\nabc"])
    bot.add_response(["this is the reply"])

    bot.reply_to(post)

    reply = post.topic.posts.order(:post_number).last

    expect(reply.raw).not_to include("abc")
    expect(reply.post_custom_prompt.custom_prompt.to_s).not_to include("abc")
    expect(reply.post_custom_prompt.custom_prompt.length).to eq(3)
    expect(reply.post_custom_prompt.custom_prompt[0][0]).to eq(
      "hello\n<function#{tags_command.strip}",
    )

    # we don't want function leftovers
    expect(reply.raw).to start_with("hello\n\n<details>")
  end
end

describe DiscourseAi::AiBot::Bot do
  before do
    SiteSetting.ai_bot_enabled_chat_bots = "gpt-4"
    SiteSetting.ai_bot_enabled = true
  end

  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT4_ID) }
  let(:bot) { described_class.as(bot_user) }

  fab!(:user) { Fabricate(:user) }
  let!(:pm) do
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
  let!(:first_post) { Fabricate(:post, topic: pm, user: user, raw: "This is a reply by the user") }
  let!(:second_post) do
    Fabricate(:post, topic: pm, user: user, raw: "This is a second reply by the user")
  end

  describe "#system_prompt" do
    it "includes relevant context in system prompt" do
      bot.system_prompt_style!(:standard)

      SiteSetting.title = "My Forum"
      SiteSetting.site_description = "My Forum Description"

      system_prompt = bot.system_prompt(second_post, allow_commands: true)

      expect(system_prompt).to include(SiteSetting.title)
      expect(system_prompt).to include(SiteSetting.site_description)

      expect(system_prompt).to include(user.username)
    end
  end

  describe "#reply_to" do
    it "can respond to a search command" do
      bot.system_prompt_style!(:simple)

      expected_response = {
        function_call: {
          name: "search",
          arguments: { query: "test search" }.to_json,
        },
      }

      prompt = bot.bot_prompt_with_topic_context(second_post, allow_commands: true)

      req_opts = bot.reply_params.merge({ functions: bot.available_functions, stream: true })

      OpenAiCompletionsInferenceStubs.stub_streamed_response(
        prompt,
        [expected_response],
        model: bot.model_for,
        req_opts: req_opts,
      )

      result =
        DiscourseAi::AiBot::Commands::SearchCommand
          .new(bot: nil, args: nil)
          .process(query: "test search")
          .to_json

      prompt << { role: "function", content: result, name: "search" }

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
        [[result, "search", "function"], ["I found nothing, sorry", bot_user.username]],
      )
      log = AiApiAuditLog.find_by(post_id: second_post.id)
      expect(log).to be_present
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
