#frozen_string_literal: true

module DiscourseAi::AiBot::Commands
  class DbSchemaCommand < Command
    class << self
      def name
        "schema"
      end

      def desc
        "Will load schema information for specific tables in the database"
      end

      def parameters
        [
          Parameter.new(
            name: "tables",
            description:
              "list of tables to load schema information for, comma seperated list eg: (users,posts))",
            type: "string",
            required: true,
          ),
        ]
      end
    end

    def result_name
      "results"
    end

    def description_args
      { tables: @tables.join(", ") }
    end

    def process(tables:)
      @tables = tables.split(",").map(&:strip)

      table_info = {}
      DB
        .query(<<~SQL, @tables)
        select table_name, column_name, data_type from information_schema.columns
        where table_schema = 'public'
        and table_name in (?)
        order by table_name
      SQL
        .each { |row| (table_info[row.table_name] ||= []) << "#{row.column_name} #{row.data_type}" }

      schema_info =
        table_info.map { |table_name, columns| "#{table_name}(#{columns.join(",")})" }.join("\n")

      { schema_info: schema_info, tables: tables }
    end
  end
end
