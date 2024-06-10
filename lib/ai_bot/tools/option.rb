# frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Tools
      class Option
        attr_reader :tool, :name, :type

        def initialize(tool:, name:, type:)
          @tool = tool
          @name = name.to_s
          @type = type
        end

        def localized_name
          I18n.t("discourse_ai.ai_bot.tool_options.#{tool.signature[:name]}.#{name}.name")
        end

        def localized_description
          I18n.t("discourse_ai.ai_bot.tool_options.#{tool.signature[:name]}.#{name}.description")
        end
      end
    end
  end
end
