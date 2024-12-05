# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class NovaTools
        def initialize(tools)
          @raw_tools = tools
        end

        def translated_tools
          return if !@raw_tools.present?

          # note: forced tools are not supported yet toolChoice is always auto
          {
            tools:
              @raw_tools.map do |tool|
                {
                  toolSpec: {
                    name: tool[:name],
                    description: tool[:description],
                    inputSchema: {
                      json: convert_tool_to_input_schema(tool),
                    },
                  },
                }
              end,
          }
        end

        # nativ tools require no system instructions
        def instructions
          ""
        end

        def from_raw_tool_call(raw_message)
          {
            toolUse: {
              toolUseId: raw_message[:id],
              name: raw_message[:name],
              input: JSON.parse(raw_message[:content])["arguments"],
            },
          }
        end

        def from_raw_tool(raw_message)
          {
            toolResult: {
              toolUseId: raw_message[:id],
              content: [{ json: JSON.parse(raw_message[:content]) }],
            },
          }
        end

        private

        def convert_tool_to_input_schema(tool)
          tool = tool.transform_keys(&:to_sym)
          properties = {}
          tool[:parameters].each do |param|
            schema = {}
            type = param[:type]
            type = "string" if !%w[string number boolean integer array].include?(type)

            schema[:type] = type

            if enum = param[:enum]
              schema[:enum] = enum
            end

            schema[:items] = { type: param[:item_type] } if type == "array"

            schema[:required] = true if param[:required]

            properties[param[:name]] = schema
          end

          { type: "object", properties: properties }
        end
      end
    end
  end
end
