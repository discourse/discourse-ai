#frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Tools::SearchSettings do
  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("open_ai:gpt-3.5-turbo") }

  before { SiteSetting.ai_bot_enabled = true }

  def search_settings(query)
    described_class.new({ query: query })
  end

  describe "#process" do
    it "can handle no results" do
      results = search_settings("this will not exist frogs").invoke(bot_user, llm)
      expect(results[:args]).to eq({ query: "this will not exist frogs" })
      expect(results[:rows]).to eq([])
    end

    it "can return more many settings with no descriptions if there are lots of hits" do
      results = search_settings("a").invoke(bot_user, llm)

      expect(results[:rows].length).to be > 30
      expect(results[:rows][0].length).to eq(1)
    end

    it "can return descriptions if there are few matches" do
      results =
        search_settings("this will not be found!@,default_locale,ai_bot_enabled_chat_bots").invoke(
          bot_user,
          llm,
        )

      expect(results[:rows].length).to eq(2)

      expect(results[:rows][0][1]).not_to eq(nil)
    end
  end
end
