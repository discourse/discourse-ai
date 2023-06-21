#frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Commands
      class Parameter
        attr_reader :name, :description, :type, :enum, :required
        def initialize(name:, description:, type:, enum: nil, required: false)
          @name = name
          @description = description
          @type = type
          @enum = enum
          @required = required
        end
      end

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

          def custom_system_message
          end

          def parameters
            raise NotImplemented
          end
        end

        attr_reader :bot_user, :args

        def initialize(bot_user, args)
          @bot_user = bot_user
          @args = args
        end

        def bot
          @bot ||= DiscourseAi::AiBot::Bot.as(bot_user)
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

        def invoke_and_attach_result_to(post, parent_post)
          placeholder = (<<~HTML).strip
            <details>
              <summary>#{I18n.t("discourse_ai.ai_bot.command_summary.#{self.class.name}")}</summary>
            </details>
          HTML

          if !post
            post =
              PostCreator.create!(
                bot_user,
                raw: placeholder,
                topic_id: parent_post.topic_id,
                skip_validations: true,
                skip_rate_limiter: true,
              )
          else
            post.revise(
              bot_user,
              { raw: post.raw + "\n\n" + placeholder + "\n\n" },
              skip_validations: true,
              skip_revision: true,
            )
          end

          post.post_custom_prompt ||= post.build_post_custom_prompt(custom_prompt: [])
          prompt = post.post_custom_prompt.custom_prompt || []

          prompt << [process(args).to_json, self.class.name, "function"]
          post.post_custom_prompt.update!(custom_prompt: prompt)

          raw = +(<<~HTML)
          <details>
            <summary>#{I18n.t("discourse_ai.ai_bot.command_summary.#{self.class.name}")}</summary>
            <p>
              #{I18n.t("discourse_ai.ai_bot.command_description.#{self.class.name}", self.description_args)}
            </p>
          </details>

          HTML

          raw << custom_raw if custom_raw.present?

          raw = post.raw.sub(placeholder, raw)

          if chain_next_response
            post.raw = raw
            post.save!(validate: false)
          else
            post.revise(bot_user, { raw: raw }, skip_validations: true, skip_revision: true)
          end

          [chain_next_response, post]
        end

        def format_results(rows, column_names = nil, args: nil)
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

          # this is not the most efficient format
          # however this is needed cause GPT 3.5 / 4 was steered using JSON
          result = { column_names: column_names, rows: rows }
          result[:args] = args if args
          result
        end

        protected

        attr_reader :bot_user, :args
      end
    end
  end
end
