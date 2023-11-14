#frozen_string_literal: true

module DiscourseAi::AiBot::Commands
  class CategoriesCommand < Command
    class << self
      def name
        "categories"
      end

      def desc
        "Will list the categories on the current discourse instance, prefer to format with # in front of the category name"
      end

      def parameters
        []
      end
    end

    def result_name
      "results"
    end

    def description_args
      { count: @last_count || 0 }
    end

    def process
      columns = {
        name: "Name",
        slug: "Slug",
        description: "Description",
        posts_year: "Posts Year",
        posts_month: "Posts Month",
        posts_week: "Posts Week",
        id: "id",
        parent_category_id: "parent_category_id",
      }

      rows = Category.where(read_restricted: false).limit(100).pluck(*columns.keys)
      @last_count = rows.length

      format_results(rows, columns.values)
    end
  end
end
