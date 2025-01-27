# frozen_string_literal: true

module DiscourseAi
  module Utils
    module DiffUtils
      class SimpleDiff
        LEVENSHTEIN_THRESHOLD = 2

        class Error < StandardError
        end
        class AmbiguousMatchError < Error
        end
        class NoMatchError < Error
        end

        def self.apply(content, search, replace)
          new.apply(content, search, replace)
        end

        def apply(content, search, replace)
          raise ArgumentError, "content cannot be nil" if content.nil?
          raise ArgumentError, "search cannot be nil" if search.nil?
          raise ArgumentError, "replace cannot be nil" if replace.nil?

          lines = content.split("\n")
          result = []
          i = 0
          found_match = false
          match_positions = find_possible_matches(lines, search)

          if match_positions.empty?
            raise NoMatchError, "Could not find a match for the search content"
          end

          if match_positions.length > 1
            raise AmbiguousMatchError,
                  "Found multiple different potential matches for the search content"
          end

          while i < lines.length
            if match_positions.include?(i)
              found_match = true
              # Skip the matched lines and add replacement
              i += search.split("\n").length
              result.concat(replace.split("\n"))
            else
              result << lines[i]
              i += 1
            end
          end

          raise NoMatchError, "Failed to apply the replacement" unless found_match

          result.join("\n")
        end

        private

        def find_possible_matches(lines, search)
          search_lines = search.split("\n")

          # First try exact matches
          exact_matches = []
          (0..lines.length - search_lines.length).each do |i|
            if lines[i].strip == search_lines.first.strip
              # Check if all subsequent lines match exactly in sequence
              if search_lines.each_with_index.all? { |search_line, idx|
                   lines[i + idx].strip == search_line.strip
                 }
                exact_matches << i
              end
            end
          end
          return exact_matches if exact_matches.any?

          # Fall back to fuzzy matches if no exact matches found
          fuzzy_matches = []
          (0..lines.length - search_lines.length).each do |i|
            if fuzzy_match?(lines[i], search_lines.first, LEVENSHTEIN_THRESHOLD)
              # Check if all subsequent lines match fuzzily in sequence
              if search_lines.each_with_index.all? { |search_line, idx|
                   fuzzy_match?(lines[i + idx], search_line, LEVENSHTEIN_THRESHOLD)
                 }
                fuzzy_matches << i
              end
            end
          end

          fuzzy_matches
        end

        def fuzzy_match?(line1, line2, threshold)
          return true if line1.strip == line2.strip

          # Remove leading whitespace for comparison
          s1 = line1.lstrip
          s2 = line2.lstrip

          distance = levenshtein_distance(s1, s2)
          distance <= threshold
        end

        def match_block?(lines, search)
          search_lines = search.split("\n")
          return false if lines.length < search_lines.length

          search_lines.each_with_index.all? do |search_line, idx|
            fuzzy_match?(lines[idx], search_line, LEVENSHTEIN_THRESHOLD)
          end
        end

        def levenshtein_distance(s1, s2)
          m = s1.length
          n = s2.length
          d = Array.new(m + 1) { Array.new(n + 1, 0) }

          (0..m).each { |i| d[i][0] = i }
          (0..n).each { |j| d[0][j] = j }

          (1..m).each do |i|
            (1..n).each do |j|
              cost = s1[i - 1] == s2[j - 1] ? 0 : 1
              d[i][j] = [
                d[i - 1][j] + 1, # deletion
                d[i][j - 1] + 1, # insertion
                d[i - 1][j - 1] + cost, # substitution
              ].min
            end
          end

          d[m][n]
        end
      end
    end
  end
end
