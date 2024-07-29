#frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Tools::SearchSettings do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("custom:#{llm_model.id}") }

  before do
    SiteSetting.ai_bot_enabled = true
    toggle_enabled_bots(bots: [llm_model])
  end

  def search_settings(query)
    described_class.new({ query: query }, bot_user: bot_user, llm: llm)
  end

  describe "#process" do
    it "can handle no results" do
      results = search_settings("this will not exist frogs").invoke
      expect(results[:args]).to eq({ query: "this will not exist frogs" })
      expect(results[:rows]).to eq([])
    end

    it "can return more many settings with no descriptions if there are lots of hits" do
      results = search_settings("a").invoke

      expect(results[:rows].length).to be > 30
      expect(results[:rows][0].length).to eq(1)
    end

    it "can return descriptions if there are few matches" do
      results = search_settings("this will not be found!@,default_locale,ai_bot_enabled").invoke

      expect(results[:rows].length).to eq(2)

      expect(results[:rows][0][1]).not_to eq(nil)
    end
  end
end
