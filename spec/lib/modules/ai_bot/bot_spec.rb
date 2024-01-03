# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Bot do
  subject(:bot) { described_class.as(bot_user) }

  before do
    SiteSetting.ai_bot_enabled_chat_bots = "gpt-4"
    SiteSetting.ai_bot_enabled = true
  end

  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT4_ID) }

  let!(:user) { Fabricate(:user) }
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
  let!(:pm_post) { Fabricate(:post, topic: pm, user: user, raw: "Does my site has tags?") }

  let(:function_call) { <<~TEXT }
    Let me try using a function to get more info:<function_calls>
    <invoke>
    <tool_name>categories</tool_name>
    </invoke>
    </function_calls>
  TEXT

  let(:response) { "As expected, your forum has multiple tags" }

  let(:llm_responses) { [function_call, response] }

  describe "#reply" do
    context "when using function chaining" do
      it "yields a loading placeholder while proceeds to invoke the command" do
        tool = DiscourseAi::AiBot::Tools::ListCategories.new({})
        partial_placeholder = +(<<~HTML).strip
        <details>
          <summary>#{tool.summary}</summary>
          <p></p>
        </details>

        HTML

        context = {}

        DiscourseAi::Completions::Llm.with_prepared_responses(llm_responses) do
          bot.reply(context) do |_bot_reply_post, cancel, placeholder|
            expect(placeholder).to eq(partial_placeholder) if placeholder
          end
        end
      end
    end
  end
end
