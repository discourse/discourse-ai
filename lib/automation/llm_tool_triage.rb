# frozen_string_literal: true
module DiscourseAi
  module Automation
    module LlmToolTriage
      def self.handle(post:, tool_id:, automation: nil)
        tool = AiTool.find_by(id: tool_id)
        return if !tool
        return if !tool.parameters.blank?

        context = {
          post_id: post.id,
          automation_id: automation&.id,
          automation_name: automation&.name,
        }

        runner = tool.runner({}, llm: nil, bot_user: Discourse.system_user, context: context)
        runner.invoke
      end
    end
  end
end
