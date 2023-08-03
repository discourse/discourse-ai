#frozen_string_literal: true

require_relative "../../../../support/openai_completions_inference_stubs"

RSpec.describe DiscourseAi::AiBot::Commands::CategoriesCommand do
  describe "#generate_categories_info" do
    it "can generate correct info" do
      Fabricate(:category, name: "america", posts_year: 999)

      info = DiscourseAi::AiBot::Commands::CategoriesCommand.new(nil, nil).process
      expect(info.to_s).to include("america")
      expect(info.to_s).to include("999")
    end
  end
end
