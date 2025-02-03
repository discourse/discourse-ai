# frozen_string_literal: true
# Inspired by Aider https://github.com/Aider-AI/aider

module DiscourseAi
  module Utils
    module DiffUtils
      # Custom errors with detailed information for LLM feedback
      class DiffError < StandardError
        attr_reader :original_text, :diff_text, :context

        def initialize(message, original_text:, diff_text:, context: {})
          @original_text = original_text
          @diff_text = diff_text
          @context = context
          super(message)
        end

        def to_llm_message
          original_text = @original_text
          original_text = @original_text[0..1000] + "..." if @original_text.length > 1000

          <<~MESSAGE
            #{message}

            Original text:
            ```
            #{original_text}
            ```

            Attempted diff:
            ```
            #{diff_text}
            ```

            #{context_message}

            Please provide a corrected diff that:
            1. Has the correct context lines
            2. Contains all necessary removals (-) and additions (+)
          MESSAGE
        end

        private

        def context_message
          return "" if context.empty?

          context.map { |key, value| "#{key}: #{value}" }.join("\n")
        end
      end

      class NoMatchingContextError < DiffError
        def initialize(original_text:, diff_text:)
          super(
            "Could not find the context lines in the original text",
            original_text: original_text,
            diff_text: diff_text,
          )
        end
      end

      class AmbiguousMatchError < DiffError
        def initialize(original_text:, diff_text:)
          super(
            "Found multiple possible locations for this change",
            original_text: original_text,
            diff_text: diff_text,
          )
        end
      end

      class MalformedDiffError < DiffError
        def initialize(original_text:, diff_text:, issue:)
          super(
            "The diff format is invalid",
            original_text: original_text,
            diff_text: diff_text,
            context: {
              "Issue" => issue,
            },
          )
        end
      end

      def self.apply_hunk(text, diff)
        # we need to handle multiple hunks just in case
        if diff.match?(/^\@\@.*\@\@$\n/)
          hunks = diff.split(/^\@\@.*\@\@$\n/)
          if hunks.present?
            hunks.each do |hunk|
              next if hunk.blank?
              text = apply_hunk(text, hunk)
            end
            return text
          end
        end

        text = text.encode(universal_newline: true)
        diff = diff.encode(universal_newline: true)
        # we need this for matching
        text = text + "\n" unless text.end_with?("\n")

        diff_lines = parse_diff_lines(diff, text)

        validate_diff_format!(text, diff, diff_lines)

        return text.strip + "\n" + diff.strip if diff_lines.all? { |marker, _| marker == " " }

        lines_to_match = diff_lines.select { |marker, _| ["-", " "].include?(marker) }.map(&:last)
        match_start, match_end = find_unique_match(text, lines_to_match, diff)
        new_hunk = diff_lines.select { |marker, _| ["+", " "].include?(marker) }.map(&:last).join

        new_hunk = +""

        diff_lines_index = 0
        text[match_start..match_end].lines.each do |line|
          diff_marker, diff_content = diff_lines[diff_lines_index]

          while diff_marker == "+"
            new_hunk << diff_content
            diff_lines_index += 1
            diff_marker, diff_content = diff_lines[diff_lines_index]
          end

          new_hunk << line if diff_marker == " "

          diff_lines_index += 1
        end

        # leftover additions
        diff_marker, diff_content = diff_lines[diff_lines_index]
        while diff_marker == "+"
          diff_lines_index += 1
          new_hunk << diff_content
          diff_marker, diff_content = diff_lines[diff_lines_index]
        end

        (text[0...match_start].to_s + new_hunk + text[match_end..-1].to_s).strip
      end

      private_class_method def self.parse_diff_lines(diff, text)
        diff.lines.map do |line|
          marker = line[0]
          content = line[1..]

          if !["-", "+", " "].include?(marker)
            marker = " "
            content = line
          end

          [marker, content]
        end
      end

      private_class_method def self.validate_diff_format!(text, diff, diff_lines)
        if diff_lines.empty?
          raise MalformedDiffError.new(original_text: text, diff_text: diff, issue: "Diff is empty")
        end
      end

      private_class_method def self.find_unique_match(text, context_lines, diff)
        return 0 if context_lines.empty? && removals.empty?

        pattern = context_lines.map { |line| "^\\s*" + Regexp.escape(line.strip) + "\s*$\n" }.join
        matches =
          text
            .enum_for(:scan, /#{pattern}/m)
            .map do
              match = Regexp.last_match
              [match.begin(0), match.end(0)]
            end

        case matches.length
        when 0
          raise NoMatchingContextError.new(original_text: text, diff_text: diff)
        when 1
          matches.first
        else
          raise AmbiguousMatchError.new(original_text: text, diff_text: diff)
        end
      end
    end
  end
end
