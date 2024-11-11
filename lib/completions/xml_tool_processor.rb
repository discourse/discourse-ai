# frozen_string_literal: true

# This class can be used to process a stream of text that may contain XML tool
# calls.
# It will return either text or ToolCall objects.

module DiscourseAi
  module Completions
    class XmlToolProcessor
      def initialize
        @buffer = +""
        @function_buffer = +""
        @should_cancel = false
        @in_tool = false
      end

      def <<(text)
        @buffer << text
        result = []

        if !@in_tool
          # double check if we are clearly in a tool
          search_length = text.length + 20
          search_string = @buffer[-search_length..-1] || @buffer

          index = search_string.rindex("<function_calls>")
          @in_tool = !!index
          if @in_tool
            @function_buffer = @buffer[index..-1]
            text_index = text.rindex("<function_calls>")
            result << text[0..text_index - 1].strip if text_index && text_index > 0
          end
        else
          @function_buffer << text
        end

        if !@in_tool
          if maybe_has_tool?(@buffer)
            split_index = text.rindex("<").to_i - 1
            if split_index >= 0
              @function_buffer = text[split_index + 1..-1] || ""
              text = text[0..split_index] || ""
            else
              @function_buffer << text
              text = ""
            end
          else
            if @function_buffer.length > 0
              result << @function_buffer
              @function_buffer = +""
            end
          end

          result << text if text.length > 0
        else
          @should_cancel = true if text.include?("</function_calls>")
        end

        result
      end

      def finish
        return [] if @function_buffer.blank?

        xml = Nokogiri::HTML5.fragment(@function_buffer)
        normalize_function_ids!(xml)
        last_invoke = xml.at("invoke:last")
        if last_invoke
          last_invoke.next_sibling.remove while last_invoke.next_sibling
          xml.at("invoke:last").add_next_sibling("\n") if !last_invoke.next_sibling
        end

        xml
          .css("invoke")
          .map do |invoke|
            tool_name = invoke.at("tool_name").content.force_encoding("UTF-8")
            tool_id = invoke.at("tool_id").content.force_encoding("UTF-8")
            parameters = {}
            invoke
              .at("parameters")
              &.children
              &.each do |node|
                next if node.text?
                name = node.name
                value = node.content.to_s
                parameters[name.to_sym] = value.to_s.force_encoding("UTF-8")
              end
            ToolCall.new(id: tool_id, name: tool_name, parameters: parameters)
          end
      end

      def should_cancel?
        @should_cancel
      end

      private

      def normalize_function_ids!(function_buffer)
        function_buffer
          .css("invoke")
          .each_with_index do |invoke, index|
            if invoke.at("tool_id")
              invoke.at("tool_id").content = "tool_#{index}" if invoke.at("tool_id").content.blank?
            else
              invoke.add_child("<tool_id>tool_#{index}</tool_id>\n") if !invoke.at("tool_id")
            end
          end
      end

      def maybe_has_tool?(text)
        # 16 is the length of function calls
        substring = text[-16..-1] || text
        split = substring.split("<")

        if split.length > 1
          match = "<" + split.last
          "<function_calls>".start_with?(match)
        else
          substring.ends_with?("<")
        end
      end
    end
  end
end
