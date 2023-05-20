#frozen_string_literal: true

module DiscourseAi::AiBot::Commands
  class CategoriesCommand < Command
    class << self
      def name
        "categories"
      end

      def desc
        "!categories - will list the categories on the current discourse instance"
      end
    end

    def result_name
      "results"
    end

    def description_args
      { count: @last_count || 0 }
    end

    def process(_args)
      info =
        +"Name, Slug, Description, Posts Year, Posts Month, Posts Week, id, parent_category_id\n"

      @count = 0
      Category
        .where(read_restricted: false)
        .limit(100)
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
          @count += 1
          info << "#{name}, #{slug}, #{(description || "").gsub(",", "")}, #{posts_year || 0}, #{posts_month || 0}, #{posts_week || 0},#{id}, #{parent_category_id} \n"
        end

      info
    end
  end
end
