# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class ClaudeTools
        def initialize(tools)
          @raw_tools = tools
        end

        def translated_tools
          # Transform the raw tools into the required Anthropic Claude API format
          raw_tools.map do |t|
            properties = {}
            required = []

            if t[:parameters]
              properties = {}

              t[:parameters].each do |param|
                mapped = { type: param[:type], description: param[:description] }
                mapped[:items] = { type: param[:item_type] } if param[:item_type]
                mapped[:enum] = param[:enum] if param[:enum]
                properties[param[:name]] = mapped
              end
              required =
                t[:parameters].select { |param| param[:required] }.map { |param| param[:name] }
            end

            {
              name: t[:name],
              description: t[:description],
              input_schema: {
                type: "object",
                properties: properties,
                required: required,
              },
            }
          end
        end

        def instructions
          ""
        end

        def from_raw_tool_call(raw_message)
          call_details = JSON.parse(raw_message[:content], symbolize_names: true)
          tool_call_id = raw_message[:id]
          [
            {
              type: "tool_use",
              id: tool_call_id,
              name: raw_message[:name],
              input: call_details[:arguments],
            },
          ]
        end

        def from_raw_tool(raw_message)
          [{ type: "tool_result", tool_use_id: raw_message[:id], content: raw_message[:content] }]
        end

        private

        attr_reader :raw_tools
      end
    end
  end
end
