# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Tools::JavascriptEvaluator do
  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("open_ai:gpt-3.5-turbo") }
  let(:progress_blk) { Proc.new {} }

  before { SiteSetting.ai_bot_enabled = true }

  describe "#invoke" do
    it "successfully evaluates a simple JavaScript expression" do
      evaluator = described_class.new({ script: "2 + 2" }, bot_user: bot_user, llm: llm)

      result = evaluator.invoke(&progress_blk)
      expect(result[:result]).to eq(4)
    end

    it "handles JavaScript execution timeout" do
      evaluator = described_class.new({ script: "while(true){}" }, bot_user: bot_user, llm: llm)

      evaluator.timeout = 5

      result = evaluator.invoke(&progress_blk)
      expect(result[:error]).to include("JavaScript execution timed out")
    end

    it "handles JavaScript memory limit exceeded" do
      evaluator =
        described_class.new(
          { script: "var a = new Array(10000); while(true) { a = a.concat(new Array(10000)) }" },
          bot_user: bot_user,
          llm: llm,
        )

      evaluator.max_memory = 10_000
      result = evaluator.invoke(&progress_blk)
      expect(result[:error]).to include("JavaScript execution exceeded memory limit")
    end

    it "returns error for invalid JavaScript syntax" do
      evaluator = described_class.new({ script: "const x =;" }, bot_user: bot_user, llm: llm)

      result = evaluator.invoke(&progress_blk)
      expect(result[:error]).to include("JavaScript execution error: ")
    end

    it "truncates long results" do
      evaluator =
        described_class.new(
          { script: "const x = 'zxn'.repeat(10000); x + 'Z';" },
          bot_user: bot_user,
          llm: llm,
        )

      result = evaluator.invoke(&progress_blk)
      expect(result[:result]).not_to include("Z")
    end

    it "returns result for more complex JavaScript" do
      evaluator =
        described_class.new(
          { script: "const x = [1, 2, 3, 4].map(n => n * 2); x.reduce((a, b) => a + b, 0);" },
          bot_user: bot_user,
          llm: llm,
        )

      result = evaluator.invoke(&progress_blk)
      expect(result[:result]).to eq(20)
    end
  end
end
