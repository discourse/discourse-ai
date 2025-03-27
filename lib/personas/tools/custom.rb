# frozen_string_literal: true

module DiscourseAi
  module Personas
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

        # Backwards compatibility: if tool_name is not set (existing custom tools), use name
        def self.name
          name, tool_name = AiTool.where(id: tool_id).pluck(:name, :tool_name).first

          tool_name.presence || name
        end

        def initialize(*args, **kwargs)
          @chain_next_response = true
          super(*args, **kwargs)
        end

        def invoke
          result = runner.invoke
          if runner.custom_raw
            self.custom_raw = runner.custom_raw
            @chain_next_response = false
          end
          result
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

        def chain_next_response?
          !!@chain_next_response
        end

        def help
          # I do not think this is called, but lets make sure
          raise "Not implemented"
        end
      end
    end
  end
end
