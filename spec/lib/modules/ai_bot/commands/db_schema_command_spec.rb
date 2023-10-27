#frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Commands::DbSchemaCommand do
  let(:command) { DiscourseAi::AiBot::Commands::DbSchemaCommand.new(bot_user: nil, args: nil) }
  describe "#process" do
    it "returns rich schema for tables" do
      result = command.process(tables: "posts,topics")
      expect(result[:schema_info]).to include("raw text")
      expect(result[:schema_info]).to include("views integer")
      expect(result[:schema_info]).to include("posts")
      expect(result[:schema_info]).to include("topics")

      expect(result[:tables]).to eq("posts,topics")
    end
  end
end
