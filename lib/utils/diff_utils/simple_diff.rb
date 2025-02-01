# frozen_string_literal: true

module DiscourseAi
  module Utils
    module DiffUtils
      class SimpleDiff
        LEVENSHTEIN_THRESHOLD = 2

        class Error < StandardError
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
          search_lines = search.split("\n")

          # First try exact matching
          match_positions =
            find_matches(lines, search_lines) { |line, search_line| line == search_line }

          # sripped match
          if match_positions.empty?
            match_positions =
              find_matches(lines, search_lines) do |line, search_line|
                line.strip == search_line.strip
              end
          end

          # Fallback to fuzzy matching if no exact matches found
          if match_positions.empty?
            match_positions =
              find_matches(lines, search_lines) do |line, search_line|
                fuzzy_match?(line, search_line)
              end
          end

          if match_positions.empty?
            raise NoMatchError, "Could not find a match for the search content"
          end

          # Replace every occurrence (process in descending order to avoid shifting indices)
          match_positions.sort.reverse.each do |pos|
            lines.slice!(pos, search_lines.length)
            lines.insert(pos, *replace.split("\n"))
          end

          lines.join("\n")
        end

        private

        def find_matches(lines, search_lines)
          matches = []
          max_index = lines.length - search_lines.length
          (0..max_index).each do |i|
            if (0...search_lines.length).all? { |j| yield(lines[i + j], search_lines[j]) }
              matches << i
            end
          end
          matches
        end

        def fuzzy_match?(line, search_line)
          return true if line.strip == search_line.strip
          s1 = line.lstrip
          s2 = search_line.lstrip
          levenshtein_distance(s1, s2) <= LEVENSHTEIN_THRESHOLD
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
              d[i][j] = [d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost].min
            end
          end
          d[m][n]
        end
      end
    end
  end
end
