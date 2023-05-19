#frozen_string_literal: true

require_relative "../../../../support/openai_completions_inference_stubs"

RSpec.describe DiscourseAi::AiBot::Commands::CategoriesCommand do
  describe "#generate_categories_info" do
    it "can generate correct info" do
      Fabricate(:category, name: "america", posts_year: 999)

      info = subject.process(nil, nil)
      expect(info).to include("america")
      expect(info).to include("999")
    end
  end
end
