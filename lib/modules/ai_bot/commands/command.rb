#frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Commands
      class Command
        class << self
          def name
            raise NotImplemented
          end

          def invoked?(cmd_name)
            cmd_name == name
          end

          def desc
            raise NotImplemented
          end

          def extra_context
            ""
          end
        end

        def initialize(bot_user, args)
          @bot_user = bot_user
          @args = args
        end

        def standalone?
          false
        end

        def low_cost?
          false
        end

        def result_name
          raise NotImplemented
        end

        def name
          raise NotImplemented
        end

        def process(post)
          raise NotImplemented
        end

        def description_args
          {}
        end

        def custom_raw
        end

        def chain_next_response
          true
        end

        def invoke_and_attach_result_to(post)
          post.post_custom_prompt ||= post.build_post_custom_prompt(custom_prompt: [])
          prompt = post.post_custom_prompt.custom_prompt || []

          prompt << ["!#{self.class.name} #{args}", bot_user.username]
          prompt << [process(args), result_name]

          post.post_custom_prompt.update!(custom_prompt: prompt)

          raw = +<<~HTML
          <details>
            <summary>#{I18n.t("discourse_ai.ai_bot.command_summary.#{self.class.name}")}</summary>
            <p>
              #{I18n.t("discourse_ai.ai_bot.command_description.#{self.class.name}", self.description_args)}
            </p>
          </details>

          HTML

          raw << custom_raw if custom_raw.present?

          if chain_next_response
            post.raw = raw
            post.save!(validate: false)
          else
            post.revise(bot_user, { raw: raw }, skip_validations: true, skip_revision: true)
          end

          chain_next_response
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

        protected

        attr_reader :bot_user, :args
      end
    end
  end
end
