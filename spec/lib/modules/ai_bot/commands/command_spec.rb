#frozen_string_literal: true

require_relative "../../../../support/openai_completions_inference_stubs"

RSpec.describe DiscourseAi::AiBot::Commands::Command do
  let(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }
  let(:command) { DiscourseAi::AiBot::Commands::GoogleCommand.new(bot_user: bot_user, args: nil) }

  before { SiteSetting.ai_bot_enabled = true }

  describe "#format_results" do
    it "can generate efficient tables of data" do
      rows = [1, 2, 3, 4, 5]
      column_names = %w[first second third]

      formatted =
        command.format_results(rows, column_names) { |row| ["row ¦ 1", row + 1, "a|b,\nc"] }

      expect(formatted[:column_names].length).to eq(3)
      expect(formatted[:rows].length).to eq(5)
      expect(formatted.to_s).to include("a|b,\\nc")
    end

    it "can also generate results by returning hash per row" do
      rows = [1, 2, 3, 4, 5]
      column_names = %w[first second third]

      formatted =
        command.format_results(rows, column_names) { |row| ["row ¦ 1", row + 1, "a|b,\nc"] }

      formatted2 =
        command.format_results(rows) do |row|
          { first: "row ¦ 1", second: row + 1, third: "a|b,\nc" }
        end

      expect(formatted).to eq(formatted2)
    end
  end
end
