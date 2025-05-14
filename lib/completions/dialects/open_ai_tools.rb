# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class OpenAiTools
        def initialize(tools)
          @raw_tools = tools
        end

        def translated_tools
          raw_tools.map do |tool|
            properties = {}
            required = []

            result = {
              name: tool.name,
              description: tool.description,
              parameters: {
                type: "object",
                properties: properties,
                required: required,
              },
            }

            tool.parameters.each do |param|
              name = param.name
              required << name if param.required
              properties[name] = { type: param.type, description: param.description }
              properties[name][:items] = { type: param.item_type } if param.item_type
              properties[name][:enum] = param.enum if param.enum
            end

            { type: "function", function: result }
          end
        end

        def instructions
          "" # Noop. Tools are listed separate.
        end

        def from_raw_tool_call(raw_message)
          call_details = JSON.parse(raw_message[:content], symbolize_names: true)
          call_details[:arguments] = call_details[:arguments].to_json
          call_details[:name] = raw_message[:name]

          {
            role: "assistant",
            content: nil,
            tool_calls: [{ type: "function", function: call_details, id: raw_message[:id] }],
          }
        end

        def from_raw_tool(raw_message)
          {
            role: "tool",
            tool_call_id: raw_message[:id],
            content: raw_message[:content],
            name: raw_message[:name],
          }
        end

        private

        attr_reader :raw_tools
      end
    end
  end
end
