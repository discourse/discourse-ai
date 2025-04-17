# frozen_string_literal: true

module DiscourseAi
  module Completions
    class StructuredOutput
      def initialize(property_names)
        @raw_response = +""
        @state = :awaiting_key
        @current_key = +""
        @escape = false

        @full_output =
          property_names.reduce({}) do |memo, pn|
            memo[pn.to_sym] = +""
            memo
          end

        # Partial output is what we processed in the last chunk.
        @partial_output_proto = @full_output.deep_dup
        @last_chunk_output = @full_output.deep_dup
      end

      attr_reader :full_output, :last_chunk_output

      def <<(raw)
        @raw_response << raw

        @last_chunk_output = @partial_output_proto.deep_dup

        raw.each_char do |char|
          case @state
          when :awaiting_key
            if char == "\""
              @current_key = +""
              @state = :parsing_key
              @escape = false
            end
          when :parsing_key
            if char == "\""
              @state = :awaiting_colon
            else
              @current_key << char
            end
          when :awaiting_colon
            @state = :awaiting_value if char == ":"
          when :awaiting_value
            if char == '"'
              @escape = false
              @state = :parsing_value
            end
          when :parsing_value
            if @escape
              # Don't add escape sequence until we know what it is
              unescaped = unescape_char(char)
              @full_output[@current_key.to_sym] << unescaped
              @last_chunk_output[@current_key.to_sym] << unescaped

              @escape = false
            elsif char == "\\"
              @escape = true
            elsif char == "\""
              @state = :awaiting_key_or_end
            else
              @full_output[@current_key.to_sym] << char
              @last_chunk_output[@current_key.to_sym] << char
            end
          when :awaiting_key_or_end
            @state = :awaiting_key if char == ","
            # End of object or whitespace ignored here
          else
            next
          end
        end
      end

      private

      def unescape_char(char)
        chars = {
          '"' => '"',
          '\\' => '\\',
          "/" => "/",
          "b" => "\b",
          "f" => "\f",
          "n" => "\n",
          "r" => "\r",
          "t" => "\t",
        }

        chars[char] || char
      end
    end
  end
end
