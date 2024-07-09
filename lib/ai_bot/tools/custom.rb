# frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Tools
      class Custom < Tool
        def self.class_instance(tool_id)
          klass = Class.new(self)
          klass.tool_id = tool_id
          klass
        end

        def self.custom?
          true
        end

        def self.tool_id
          @tool_id
        end

        def self.tool_id=(tool_id)
          @tool_id = tool_id
        end

        def self.signature
          AiTool.find(tool_id).signature
        end

        def self.name
          AiTool.where(id: tool_id).pluck(:name).first
        end

        def invoke
          runner.invoke
        end

        def runner
          @runner ||= ai_tool.runner(parameters, llm: llm, bot_user: bot_user, context: context)
        end

        def ai_tool
          @ai_tool ||= AiTool.find(self.class.tool_id)
        end

        def summary
          ai_tool.summary
        end

        def details
          runner.details
        end

        def help
          # I do not think this is called, but lets make sure
          raise "Not implemented"
        end
      end
    end
  end
end
