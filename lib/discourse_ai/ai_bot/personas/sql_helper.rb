#frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Personas
      class SqlHelper < Persona
        def self.schema
          return @schema if defined?(@schema)

          tables = Hash.new
          priority_tables = %w[posts topics notifications users user_actions user_emails]

          DB.query(<<~SQL).each { |row| (tables[row.table_name] ||= []) << row.column_name }
        select table_name, column_name from information_schema.columns
        where table_schema = 'public'
        order by table_name
      SQL

          schema = +(priority_tables.map { |name| "#{name}(#{tables[name].join(",")})" }.join("\n"))

          schema << "\nOther tables (schema redacted, available on request): "
          tables.each do |table_name, _|
            next if priority_tables.include?(table_name)
            schema << "#{table_name} "
          end

          @schema = schema
        end

        def commands
          all_available_commands
        end

        def all_available_commands
          [DiscourseAi::AiBot::Commands::DbSchemaCommand]
        end

        def system_prompt
          <<~PROMPT
            You are a PostgreSQL expert.
            - You understand and generate Discourse Markdown but specialize in creating queries.
            - You live in a Discourse Forum Message.
            - The schema in your training set MAY be out of date.
            - When generating SQL NEVER end SQL samples with a semicolon (;).
            - When generating SQL always use ```sql markdown code blocks.
            - Always format SQL in a highly readable format.

            Eg:

            ```sql
            select 1 from table
            ```

            The user_actions tables stores likes (action_type 1).
            the topics table stores private/personal messages it uses archetype private_message for them.
            notification_level can be: {muted: 0, regular: 1, tracking: 2, watching: 3, watching_first_post: 4}.
            bookmarkable_type can be: Post,Topic,ChatMessage and more

            Current time is: {time}


            The current schema for the current DB is:
            {{
            #{self.class.schema}
            }}
          PROMPT
        end
      end
    end
  end
end
