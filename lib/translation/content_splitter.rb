# frozen_string_literal: true

module DiscourseAi
  module Translation
    class ContentSplitter
      CHUNK_SIZE = 3000

      BBCODE_PATTERNS = [
        %r{\[table.*?\].*?\[/table\]}m,
        %r{\[quote.*?\].*?\[/quote\]}m,
        %r{\[details.*?\].*?\[/details\]}m,
        %r{\<details.*?\>.*?\</details\>}m,
        %r{\[spoiler.*?\].*?\[/spoiler\]}m,
        %r{\[code.*?\].*?\[/code\]}m,
        /```.*?```/m,
      ].freeze

      TEXT_BOUNDARIES = [
        /\n\s*\n\s*|\r\n\s*\r\n\s*/, # double newlines with optional spaces
        /[.!?]\s+/, # sentence endings
        /[,;]\s+/, # clause endings
        /\n|\r\n/, # single newlines
        /\s+/, # any whitespace
      ].freeze

      def self.split(content)
        return [] if content.nil?
        return [""] if content.empty?
        return [content] if content.length <= CHUNK_SIZE

        chunks = []
        remaining = content.dup

        while remaining.present?
          chunk = extract_mixed_chunk(remaining)
          break if chunk.empty?
          chunks << chunk
          remaining = remaining[chunk.length..-1]
        end

        chunks
      end

      private

      def self.extract_mixed_chunk(text, size: CHUNK_SIZE)
        return text if text.length <= size
        flexible_size = size * 1.5

        # try each splitting strategy in order
        split_point =
          [
            -> { find_nearest_html_end_index(text, size) },
            -> { find_nearest_bbcode_end_index(text, size) },
            -> { find_text_boundary(text, size) },
            -> { size },
          ].lazy.map(&:call).compact.find { |pos| pos <= flexible_size }

        text[0...split_point]
      end

      def self.find_nearest_html_end_index(text, target_pos)
        return nil if !text.include?("<")

        begin
          doc = Nokogiri::HTML5.fragment(text)
          current_length = 0

          doc.children.each do |node|
            html = node.to_html
            end_pos = current_length + html.length
            return end_pos if end_pos > target_pos
            current_length = end_pos
          end
          nil
        rescue Nokogiri::SyntaxError
          nil
        end
      end

      def self.find_nearest_bbcode_end_index(text, target_pos)
        BBCODE_PATTERNS.each do |pattern|
          text.scan(pattern) do |_|
            match = $~
            tag_start = match.begin(0)
            tag_end = match.end(0)

            return tag_end if tag_start <= target_pos && tag_end > target_pos
          end
        end

        nil
      end

      def self.find_text_boundary(text, target_pos)
        search_text = text

        TEXT_BOUNDARIES.each do |pattern|
          if pos = search_text.rindex(pattern, target_pos)
            # Include all trailing whitespace
            pos += 1 while pos < search_text.length && search_text[pos].match?(/\s/)
            return pos
          end
        end
        nil
      end
    end
  end
end
