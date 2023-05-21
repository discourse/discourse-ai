#frozen_string_literal: true

require_relative "../../../../support/openai_completions_inference_stubs"

RSpec.describe DiscourseAi::AiBot::Commands::Command do
  fab!(:bot_user) { User.find(DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID) }
  let(:command) { DiscourseAi::AiBot::Commands::Command.new(bot_user, nil) }

  describe "#format_results" do
    it "can generate efficient tables of data" do
      rows = [1, 2, 3, 4, 5]
      column_names = %w[first second third]

      formatted =
        command.format_results(rows, column_names) { |row| ["row ¦ 1", row + 1, "a|b,\nc"] }

      expect(formatted.split("\n").length).to eq(6)
      expect(formatted).to include("a|b, c")
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
