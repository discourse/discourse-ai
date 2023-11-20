#frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Commands::CategoriesCommand do
  describe "#generate_categories_info" do
    it "can generate correct info" do
      Fabricate(:category, name: "america", posts_year: 999)

      info = DiscourseAi::AiBot::Commands::CategoriesCommand.new(bot: nil, args: nil).process
      expect(info.to_s).to include("america")
      expect(info.to_s).to include("999")
    end
  end
end
