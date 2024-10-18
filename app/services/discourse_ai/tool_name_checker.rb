# frozen_string_literal: true

module DiscourseAi
  class ToolNameChecker
    def initialize(tool_name)
      @tool_name = tool_name
    end

    def check
      if @tool_name.match? AiTool::ALPHANUMERIC_PATTERN
        check_name_availability
      else
        { available: false, errors: [I18n.t("discourse_ai.tools.name.characters")] }
      end
    end

    private

    def check_name_availability
      if AiTool.exists?(name: @tool_name)
        { available: false, errors: [I18n.t("errors.messages.taken")] }
      else
        { available: true }
      end
    end
  end
end
