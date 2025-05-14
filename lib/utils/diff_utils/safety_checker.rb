# frozen_string_literal: true

require "cgi"

module DiscourseAi
  module Utils
    module DiffUtils
      class SafetyChecker
        def self.safe_to_stream?(html_text)
          new(html_text).safe?
        end

        def initialize(html_text)
          @original_html = html_text
          @text = sanitize(html_text)
        end

        def safe?
          return false if unclosed_markdown_links?
          return false if unclosed_raw_html_tag?
          return false if trailing_incomplete_url?
          return false if unclosed_backticks?
          return false if unbalanced_bold_or_italic?
          return false if incomplete_image_markdown?
          return false if unbalanced_quote_blocks?
          return false if unclosed_triple_backticks?
          return false if partial_emoji?

          true
        end

        private

        def sanitize(html)
          text = html.gsub(%r{</?[^>]+>}, "") # remove tags like <span>, <del>, etc.
          CGI.unescapeHTML(text)
        end

        def unclosed_markdown_links?
          open_bracket = @text.rindex("[")
          close_bracket = @text.rindex("]")
          open_paren = @text.rindex("(")
          close_paren = @text.rindex(")")
          open_bracket && open_paren && (close_bracket.nil? || close_paren.nil?)
        end

        def unclosed_raw_html_tag?
          last_lt = @text.rindex("<")
          last_gt = @text.rindex(">")
          last_lt && (!last_gt || last_gt < last_lt)
        end

        def trailing_incomplete_url?
          last_word = @text.split(/\s/).last
          last_word =~ %r{\Ahttps?://[^\s]*\z} && last_word !~ /[)\].,!?:;'"]\z/
        end

        def unclosed_backticks?
          @text.count("`").odd?
        end

        def unbalanced_bold_or_italic?
          @text.scan(/\*\*/).count.odd? || @text.scan(/\*(?!\*)/).count.odd? ||
            @text.scan(/_/).count.odd?
        end

        def incomplete_image_markdown?
          last_image = @text[/!\[.*?\]\(.*?$/, 0]
          last_image && last_image[-1] != ")"
        end

        def unbalanced_quote_blocks?
          opens = @text.scan(/\[quote(=.*?)?\]/i).count
          closes = @text.scan(%r{\[/quote\]}i).count
          opens > closes
        end

        def unclosed_triple_backticks?
          @text.scan(/```/).count.odd?
        end

        def partial_emoji?
          @text
            .scan(/:[a-z0-9_+.-]*:?/i)
            .any? do |match|
              match.count(":") == 1 || (match[-1] != ":" && match =~ /:[a-z0-9_+-]+\.\z/i)
            end
        end
      end
    end
  end
end
