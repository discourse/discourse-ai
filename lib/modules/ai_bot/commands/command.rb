#frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Commands
      class Command
        class << self
          def name
            raise NotImplemented
          end

          def should_invoke?(cmd_name)
            cmd_name == name
          end

          def desc
            raise NotImplemented
          end

          def extra_context
            ""
          end
        end

        attr_reader :bot_user, :args, :post

        def initialize(bot_user, post, args)
          @bot_user = bot_user
          @args = args
          @post = post
        end

        def bot
          @bot ||= DiscourseAi::AiBot::Bot.as(bot_user)
        end

        def result_name
          raise NotImplemented
        end

        def name
          raise NotImplemented
        end

        def process
          raise NotImplemented
        end

        def description_args
          {}
        end

        def chain_next_response
          true
        end

        def pre_raw_details
          I18n.t("discourse_ai.ai_bot.command_summary.#{self.class.name}")
        end

        def post_raw_details
          +<<~HTML
          <details>
            <summary>#{I18n.t("discourse_ai.ai_bot.command_summary.#{self.class.name}")}</summary>
            <p>
              #{I18n.t("discourse_ai.ai_bot.command_description.#{self.class.name}", self.description_args)}
            </p>
          </details>
          HTML
        end

        def format_results(rows, column_names = nil)
          rows = rows.map { |row| yield row } if block_given?

          if !column_names
            index = -1
            column_indexes = {}

            rows =
              rows.map do |data|
                new_row = []
                data.each do |key, value|
                  found_index = column_indexes[key.to_s] ||= (index += 1)
                  new_row[found_index] = value
                end
                new_row
              end
            column_names = column_indexes.keys
          end
          # two tokens per delimiter is a reasonable balance
          # there may be a single delimiter solution but GPT has
          # a hard time dealing with escaped characters
          delimiter = "¦"
          formatted = +""
          formatted << column_names.join(delimiter)
          formatted << "\n"

          rows.each do |array|
            array.map! { |item| item.to_s.gsub(delimiter, "|").gsub(/\n/, " ") }
            formatted << array.join(delimiter)
            formatted << "\n"
          end

          formatted
        end
      end
    end
  end
end
