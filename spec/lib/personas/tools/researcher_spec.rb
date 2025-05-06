# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::Researcher do
  before { SearchIndexer.enable }
  after { SearchIndexer.disable }

  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("custom:#{llm_model.id}") }
  let(:progress_blk) { Proc.new {} }

  fab!(:admin)
  fab!(:user)
  fab!(:category) { Fabricate(:category, name: "research-category") }
  fab!(:tag_research) { Fabricate(:tag, name: "research") }
  fab!(:tag_data) { Fabricate(:tag, name: "data") }

  fab!(:topic_with_tags) { Fabricate(:topic, category: category, tags: [tag_research, tag_data]) }
  fab!(:post) { Fabricate(:post, topic: topic_with_tags) }

  before { SiteSetting.ai_bot_enabled = true }

  describe "#invoke" do
    it "returns filter information and result count" do
      researcher =
        described_class.new(
          { filter: "tag:research after:2023", goal: "analyze post patterns" },
          bot_user: bot_user,
          llm: llm,
          context: DiscourseAi::Personas::BotContext.new(user: user),
        )

      results = researcher.invoke(&progress_blk)

      expect(results[:filter]).to eq("tag:research after:2023")
      expect(results[:goal]).to eq("analyze post patterns")
      expect(results[:dry_run]).to eq(true)
      expect(results[:number_of_results]).to be > 0
      expect(researcher.last_filter).to eq("tag:research after:2023")
      expect(researcher.result_count).to be > 0
    end

    it "handles empty filters" do
      researcher =
        described_class.new({ goal: "analyze all content" }, bot_user: bot_user, llm: llm)

      results = researcher.invoke(&progress_blk)

      expect(results[:filter]).to eq("")
      expect(results[:goal]).to eq("analyze all content")
      expect(researcher.last_filter).to eq("")
    end

    it "accepts max_results option" do
      researcher =
        described_class.new(
          { filter: "category:research-category" },
          persona_options: {
            "max_results" => "50",
          },
          bot_user: bot_user,
          llm: llm,
        )

      expect(researcher.options[:max_results]).to eq(50)
    end
  end
end
