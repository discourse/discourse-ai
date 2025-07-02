# frozen_string_literal: true

module DiscourseAi
  module Translation
    class PostDetectionText
      def self.get_text(post)
        return if post.blank?
        cooked = post.cooked
        return if cooked.blank?

        doc = Nokogiri::HTML.fragment(cooked)
        original = doc.text.strip

        # quotes and blockquotes
        doc.css("blockquote, aside.quote").remove
        # image captions
        doc.css(".lightbox-wrapper").remove

        necessary = doc.text.strip

        # oneboxes (external content)
        doc.css("aside.onebox").remove
        # code blocks
        doc.css("code, pre").remove
        # hashtags
        doc.css("a.hashtag-cooked").remove
        # emoji
        doc.css("img.emoji").remove
        # mentions
        doc.css("a.mention").remove

        preferred = doc.text.strip

        return preferred if preferred.present?
        return necessary if necessary.present?
        original
      end
    end
  end
end
