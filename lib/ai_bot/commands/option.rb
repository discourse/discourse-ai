# frozen_string_literal: true
module DiscourseAi
  module AiBot
    module Commands
      class Option
        attr_reader :command, :name, :type
        def initialize(command:, name:, type:)
          @command = command
          @name = name.to_s
          @type = type
        end

        def localized_name
          I18n.t("discourse_ai.ai_bot.command_options.#{command.name}.#{name}.name")
        end

        def localized_description
          I18n.t("discourse_ai.ai_bot.command_options.#{command.name}.#{name}.description")
        end
      end
    end
  end
end
