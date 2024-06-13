# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Bot do
  subject(:bot) { described_class.as(bot_user) }

  fab!(:admin)
  fab!(:gpt_4) { Fabricate(:llm_model, name: "gpt-4") }
  fab!(:fake) { Fabricate(:llm_model, name: "fake", provider: "fake") }

  before do
    SiteSetting.ai_bot_enabled_chat_bots = gpt_4.name
    SiteSetting.ai_bot_enabled = true
  end

  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model("gpt-4") }

  let!(:user) { Fabricate(:user) }

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
    it "sets top_p and temperature params" do
      # full integration test so we have certainty it is passed through

      DiscourseAi::Completions::Endpoints::Fake.delays = []
      DiscourseAi::Completions::Endpoints::Fake.last_call = nil

      SiteSetting.ai_bot_enabled_chat_bots = fake.name
      SiteSetting.ai_bot_enabled = true
      Group.refresh_automatic_groups!

      bot_user = DiscourseAi::AiBot::EntryPoint.find_user_from_model("fake")
      AiPersona.create!(
        name: "TestPersona",
        top_p: 0.5,
        temperature: 0.4,
        system_prompt: "test",
        description: "test",
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
      )

      personaClass = DiscourseAi::AiBot::Personas::Persona.find_by(user: admin, name: "TestPersona")

      bot = DiscourseAi::AiBot::Bot.as(bot_user, persona: personaClass.new)
      bot.reply(
        { conversation_context: [{ type: :user, content: "test" }] },
      ) do |_partial, _cancel, _placeholder|
        # we just need the block so bot has something to call with results
      end

      last_call = DiscourseAi::Completions::Endpoints::Fake.last_call
      expect(last_call[:model_params][:top_p]).to eq(0.5)
      expect(last_call[:model_params][:temperature]).to eq(0.4)
    end

    context "when using function chaining" do
      it "yields a loading placeholder while proceeds to invoke the command" do
        tool = DiscourseAi::AiBot::Tools::ListCategories.new({}, bot_user: nil, llm: nil)
        partial_placeholder = +(<<~HTML)
        <details>
          <summary>#{tool.summary}</summary>
          <p></p>
        </details>
        <span></span>

        HTML

        context = { conversation_context: [{ type: :user, content: "Does my site has tags?" }] }

        DiscourseAi::Completions::Llm.with_prepared_responses(llm_responses) do
          bot.reply(context) do |_bot_reply_post, cancel, placeholder|
            expect(placeholder).to eq(partial_placeholder) if placeholder
          end
        end
      end
    end
  end
end
