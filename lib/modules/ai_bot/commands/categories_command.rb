#frozen_string_literal: true

module DiscourseAi::AiBot::Commands
  class CategoriesCommand < Command
    def result_name
      "results"
    end

    def name
      "categories"
    end

    def process(_post, _ignore)
      info =
        +"Name, Slug, Description, Posts Year, Posts Month, Posts Week, id, parent_category_id\n"

      Category
        .where(read_restricted: false)
        .pluck(
          :id,
          :parent_category_id,
          :slug,
          :name,
          :description,
          :posts_year,
          :posts_month,
          :posts_week,
        )
        .map do |id, parent_category_id, slug, name, description, posts_year, posts_month, posts_week|
          info << "#{name}, #{slug}, #{(description || "").gsub(",", "")}, #{posts_year || 0}, #{posts_month || 0}, #{posts_week || 0},#{id}, #{parent_category_id} \n"
        end

      info
    end
  end
end
