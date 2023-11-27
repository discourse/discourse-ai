# frozen_string_literal: true

module ::DiscourseAi
  module Inference
    class FunctionList
      def initialize
        @functions = []
      end

      def <<(function)
        @functions << function
      end

      def parse_prompt(prompt)
        xml = prompt.sub(%r{<function_calls>(.*)</function_calls>}m, '\1')
        if xml.present?
          parsed = []
          Nokogiri
            .XML(xml)
            .xpath("//invoke")
            .each do |invoke_node|
              function = { name: invoke_node.xpath("//tool_name").text, arguments: {} }
              parsed << function
              invoke_node
                .xpath("//parameters")
                .children
                .each do |parameters_node|
                  if parameters_node.is_a?(Nokogiri::XML::Element) && name = parameters_node.name
                    function[:arguments][name.to_sym] = parameters_node.text
                  end
                end
            end
          coerce_arguments!(parsed)
        end
      end

      def coerce_arguments!(parsed)
        parsed.each do |function_call|
          arguments = function_call[:arguments]

          function = @functions.find { |f| f.name == function_call[:name] }
          next if !function

          arguments.each do |name, value|
            parameter = function.parameters.find { |p| p[:name].to_s == name.to_s }
            if !parameter
              arguments.delete(name)
              next
            end

            type = parameter[:type]
            if type == "array"
              arguments[name] = begin
                JSON.parse(value)
              rescue StandardError
              end
              # TODO consider other heuristics as well
              arguments[name] ||= value.split("\n").map(&:strip).reject(&:blank?)
            elsif type == "integer"
              arguments[name] = value.to_i
            elsif type == "float"
              arguments[name] = value.to_f
            end
          end
        end
        parsed
      end

      def system_prompt
        tools = +""

        @functions.each do |function|
          parameters = +""
          if function.parameters.present?
            parameters << "\n"
            function.parameters.each do |parameter|
              parameters << <<~PARAMETER
                <parameter>
                <name>#{parameter[:name]}</name>
                <type>#{parameter[:type]}</type>
                <description>#{parameter[:description]}</description>
                <required>#{parameter[:required]}</required>
              PARAMETER
              parameters << "<options>#{parameter[:enum].join(",")}</options>\n" if parameter[:enum]
              parameters << "</parameter>\n"
            end
          end

          tools << <<~TOOLS
            <tool_description>
            <tool_name>#{function.name}</tool_name>
            <description>#{function.description}</description>
            <parameters>#{parameters}</parameters>
            </tool_description>
          TOOLS
        end

        <<~PROMPT
          In this environment you have access to a set of tools you can use to answer the user's question.
          You may call them like this. Only invoke one function at a time and wait for the results before invoking another function:
          <function_calls>
          <invoke>
          <tool_name>$TOOL_NAME</tool_name>
          <parameters>
          <$PARAMETER_NAME>$PARAMETER_VALUE</$PARAMETER_NAME>
          ...
          </parameters>
          </invoke>
          </function_calls>

          Here are the tools available:

          <tools>
          #{tools}</tools>
        PROMPT
      end
    end
  end
end
