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
        parsed = []

        prompt
          .split("\n")
          .each do |line|
            line.strip!
            next if line.blank?
            next if !line.start_with?("!")

            name, arguments = line.split("(", 2)
            name = name[1..-1].strip

            function = @functions.find { |f| f.name == name }
            next if function.blank?

            arguments = arguments[0..-2] if arguments.end_with?(")")
            arguments = arguments.split(",").map(&:strip)

            parsed_arguments = {}
            arguments.each do |argument|
              key, value = argument.split(":", 2)
              # remove stuff that is bypasses spec
              param = function.parameters.find { |p| p[:name] == key.strip }
              next if !param

              value = value.strip.gsub(/(\A"(.*)"\Z)|(\A'(.*)'\Z)/m, '\2\4') if value.present?

              if param[:enum]
                next if !param[:enum].include?(value)
              end

              parsed_arguments[key.strip.to_sym] = value.strip
            end

            # ensure parsed_arguments has all required arguments
            all_good = true
            function.parameters.each do |parameter|
              next if !parameter[:required]
              next if parsed_arguments[parameter[:name].to_sym].present?

              all_good = false
              break
            end

            parsed << { name: name, arguments: parsed_arguments } if all_good
          end

        parsed
      end

      def system_prompt
        prompt = +<<~PROMPT
          - You are able to execute the following external functions on real data!
          - Never say that you are in a hypothetical situation, just run functions you need to run!
          - When you run a command/function you will gain access to real information in a subsequant call!

          {
        PROMPT

        @functions.each do |function|
          prompt << " // #{function.description}\n"
          prompt << " #{function.name}"
          if function.parameters.present?
            prompt << "("
            function.parameters.each_with_index do |parameter, index|
              prompt << ", " if index > 0
              prompt << "#{parameter[:name]}: #{parameter[:type]}"
              if parameter[:required]
                prompt << " [required]"
              else
                prompt << " [optional]"
              end

              description = +(parameter[:description] || "")
              description << " [valid values: #{parameter[:enum].join(",")}]" if parameter[:enum]

              description.strip!

              prompt << " /* #{description} */" if description.present?
            end
            prompt << ")\n"
          end
        end

        prompt << <<~PROMPT
          }
          \n\nTo execute a function, use the following syntax:

          !function_name(param1: "value1", param2: 2)

          For example for a function defined as:

          {
            // echo a string
            echo(message: string [required])
          }

          You can execute with:
          !echo(message: "hello world")
        PROMPT

        prompt
      end
    end
  end
end
