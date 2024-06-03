# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class CohereTools
        def initialize(tools)
          @raw_tools = tools
        end

        def tool_results(messages)
          pairs = []

          current_pair = nil
          messages.each do |msg|
            if current_pair == nil && msg[:type] == :tool_call
              current_pair = [msg]
            elsif current_pair && msg[:type] == :tool
              current_pair << msg
              pairs << current_pair
              current_pair = nil
            else
              current_pair = nil
            end
          end

          pairs.map do |call, result|
            params = JSON.parse(call[:content])[:arguments]
            {
              call: {
                name: call[:name],
                parameters: params,
                generation_id: call[:id],
              },
              outputs: result[:content],
            }
          end
        end

        def translated_tools
          raw_tools.map do |t|
            tool = t.dup

            tool[:parameter_definitions] = t[:parameters]
              .to_a
              .reduce({}) do |memo, p|
                name = p[:name]
                memo[name] = {
                  description: p[:description],
                  type: cohere_type(p[:type], p[:item_type]),
                  required: p[:required],
                }

                memo[name][:default] = p[:default] if p[:default]
                memo
              end

            {
              name: tool[:name],
              description: tool[:description],
              parameter_definitions: tool[:parameter_definitions],
            }
          end
        end

        def instructions
          "" # Noop. Tools are listed separate.
        end

        private

        attr_reader :raw_tools

        def cohere_type(type, item_type)
          case type
          when "string"
            "str"
          when "number"
            item_type == "integer" ? "int" : "float"
          when "boolean"
            "bool"
          when "object"
            item_type ? "Dict[#{item_type}]" : "Dict"
          when "array"
            item_type ? "List[#{item_type}]" : "List"
          else
            type
          end
        end
      end
    end
  end
end
