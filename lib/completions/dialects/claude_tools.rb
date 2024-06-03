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
            {
              name: t[:name],
              description: t[:description],
              input_schema: {
                type: "object",
                properties:
                  t[:parameters].each_with_object({}) do |param, h|
                    h[param[:name]] = {
                      type: param[:type],
                      description: param[:description],
                    }.tap { |hash| hash[:items] = { type: param[:item_type] } if param[:item_type] }
                  end,
                required:
                  t[:parameters].select { |param| param[:required] }.map { |param| param[:name] },
              },
            }
          end
        end

        def instructions
          "" # Noop. Tools are listed separate.
        end

        def from_raw_tool_call(raw_message)
          call_details = JSON.parse(raw_message[:content], symbolize_names: true)
          tool_call_id = raw_message[:id]
          call_details[:arguments] = JSON.generate(call_details[:arguments])

          p raw_message

          {
            role: "assistant",
            content: {
              type: "tool_use",
              id: tool_call_id,
              name: raw_message[:name],
              input: call_details[:arguments],
            }.to_json.to_s,
          }
        end

        def from_raw_tool(raw_message)
          p raw_message
          {
            role: "user",
            content: {
              type: "tool_result",
              tool_use_id: raw_message[:id],
              content: raw_message[:content],
            }.to_json.to_s,
          }
        end

        private

        attr_reader :raw_tools
      end
    end
  end
end
