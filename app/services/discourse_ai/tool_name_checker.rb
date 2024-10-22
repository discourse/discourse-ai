# frozen_string_literal: true

module DiscourseAi
  class ToolNameChecker
    def initialize(tool_name)
      @tool_name = tool_name
    end

    def check
      if @tool_name.match? AiTool::ALPHANUMERIC_PATTERN
        { available: true }
      else
        { available: false, errors: [I18n.t("discourse_ai.tools.name.characters")] }
      end
    end
  end
end
